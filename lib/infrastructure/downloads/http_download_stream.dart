import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:kidflix/core/domain/model/movie_download.dart';

/// Shared download streaming primitive used by every [DownloadRepository]
/// implementation.
///
/// Each caller provides its own [Dio] so an in-memory repo can hit a
/// third-party URL without leaking auth headers, while a backend-bound
/// repo can hit a relative path under `dio.options.baseUrl` and rely on
/// the registered `AuthInterceptor`. The helper is the single source of
/// truth for the `.partial` → `.mp4` rename, the 2 MiB + 3% `readyToPlay`
/// threshold, the 4 Hz progress throttling, and the `Range` resume
/// semantics.
///
/// The returned stream is single-subscription — callers that need a
/// broadcast stream wrap it in their own `StreamController.broadcast()`.
/// The stream completes when the download reaches a terminal status
/// (`complete`, `failed`, `cancelled`).
Stream<MovieDownload> streamHttpDownload({
  required Dio dio,
  required String url,
  required String movieId,
  required Directory downloadsDir,
  required CancelToken cancelToken,
  required bool Function() isCancelled,
}) {
  final controller = StreamController<MovieDownload>();
  unawaited(
    _runDownload(
      controller: controller,
      dio: dio,
      url: url,
      movieId: movieId,
      downloadsDir: downloadsDir,
      cancelToken: cancelToken,
      isCancelled: isCancelled,
    ),
  );
  return controller.stream;
}

/// Inspects the filesystem for a previously-completed or interrupted
/// download of [movieId] and returns a synthetic [MovieDownload]
/// snapshot if a `.mp4` (complete) or `.mp4.partial` (cancelled) is
/// found on disk. Returns `null` when neither file exists.
///
/// Issues no HTTP request and depends on no in-process state.
Future<MovieDownload?> inspectDownloadOnDisk({
  required String movieId,
  required Directory downloadsDir,
}) async {
  final finalFile = File(_finalPath(movieId, downloadsDir));
  if (await finalFile.exists()) {
    final size = await finalFile.length();
    return MovieDownload(
      movieId: movieId,
      status: DownloadStatus.complete,
      bytesReceived: size,
      bytesTotal: size,
      localPath: finalFile.path,
      updatedAt: await finalFile.lastModified(),
    );
  }
  final partialFile = File(_partialPath(movieId, downloadsDir));
  if (await partialFile.exists()) {
    final size = await partialFile.length();
    return MovieDownload(
      movieId: movieId,
      status: DownloadStatus.cancelled,
      bytesReceived: size,
      localPath: partialFile.path,
      updatedAt: await partialFile.lastModified(),
    );
  }
  return null;
}

const _readyThresholdBytes = 2 * 1024 * 1024;
const _readyThresholdFraction = 0.03;
const _throttleInterval = Duration(milliseconds: 250);

String _finalPath(String movieId, Directory dir) =>
    '${dir.path}/$movieId.mp4';

String _partialPath(String movieId, Directory dir) =>
    '${dir.path}/$movieId.mp4.partial';

Future<void> _runDownload({
  required StreamController<MovieDownload> controller,
  required Dio dio,
  required String url,
  required String movieId,
  required Directory downloadsDir,
  required CancelToken cancelToken,
  required bool Function() isCancelled,
}) async {
  try {
    if (!await downloadsDir.exists()) {
      await downloadsDir.create(recursive: true);
    }

    final finalFile = File(_finalPath(movieId, downloadsDir));
    if (await finalFile.exists()) {
      final size = await finalFile.length();
      controller.add(
        MovieDownload(
          movieId: movieId,
          status: DownloadStatus.complete,
          bytesReceived: size,
          bytesTotal: size,
          localPath: finalFile.path,
          updatedAt: DateTime.now(),
        ),
      );
      await controller.close();
      return;
    }

    final partialFile = File(_partialPath(movieId, downloadsDir));
    final initialBytes = await partialFile.exists()
        ? await partialFile.length()
        : 0;

    final Response<ResponseBody> response;
    try {
      // Always send a Range header (even `bytes=0-`): when the server replies
      // 206 it must include `Content-Range: bytes <a>-<b>/<total>`, which is
      // our only source of truth for the total size when the body is sent
      // with `Transfer-Encoding: chunked` (no `Content-Length`). Servers that
      // don't honor Range will fall through to a 200 with the full body.
      response = await dio.get<ResponseBody>(
        url,
        options: Options(
          responseType: ResponseType.stream,
          headers: {HttpHeaders.rangeHeader: 'bytes=$initialBytes-'},
        ),
        cancelToken: cancelToken,
      );
    } on DioException catch (e) {
      if (isCancelled() || CancelToken.isCancel(e)) {
        await _emitCancelled(controller, movieId, partialFile, initialBytes);
      } else {
        await _emitFailed(controller, movieId, e.message ?? 'Download failed', partialFile);
      }
      return;
    }

    final statusCode = response.statusCode ?? 0;
    // Trust the actual range the server is sending over the bare status code:
    // some backends return 206 while still serving the full file from byte 0,
    // which would make a naive append double the file size on every retry.
    final actualRangeStart = _parseContentRangeStart(
      response.headers.value('content-range'),
    );
    final serverAcceptedRange =
        statusCode == 206 && actualRangeStart == initialBytes;

    var bytesReceived = serverAcceptedRange ? initialBytes : 0;
    if (!serverAcceptedRange && await partialFile.exists()) {
      await partialFile.delete();
    }
    if (!await partialFile.exists()) {
      await partialFile.create(recursive: true);
    }

    final bytesTotal = _resolveTotalSize(response.headers, bytesReceived);

    final sink = partialFile.openWrite(mode: FileMode.writeOnlyAppend);

    controller.add(
      MovieDownload(
        movieId: movieId,
        status: DownloadStatus.downloading,
        bytesReceived: bytesReceived,
        bytesTotal: bytesTotal,
        updatedAt: DateTime.now(),
      ),
    );

    var readyEmitted = false;
    var lastThrottledEmit = DateTime.now();

    try {
      await for (final chunk in response.data!.stream) {
        sink.add(chunk);
        bytesReceived += chunk.length;

        if (!readyEmitted && _meetsReadyThreshold(bytesReceived, bytesTotal)) {
          readyEmitted = true;
          controller.add(
            MovieDownload(
              movieId: movieId,
              status: DownloadStatus.readyToPlay,
              bytesReceived: bytesReceived,
              bytesTotal: bytesTotal,
              localPath: partialFile.path,
              updatedAt: DateTime.now(),
            ),
          );
          lastThrottledEmit = DateTime.now();
          continue;
        }

        final now = DateTime.now();
        if (now.difference(lastThrottledEmit) >= _throttleInterval) {
          lastThrottledEmit = now;
          controller.add(
            MovieDownload(
              movieId: movieId,
              status: readyEmitted
                  ? DownloadStatus.readyToPlay
                  : DownloadStatus.downloading,
              bytesReceived: bytesReceived,
              bytesTotal: bytesTotal,
              localPath: readyEmitted ? partialFile.path : null,
              updatedAt: now,
            ),
          );
        }
      }
    } catch (e) {
      await sink.flush();
      await sink.close();
      if (isCancelled() || (e is DioException && CancelToken.isCancel(e))) {
        await _emitCancelled(controller, movieId, partialFile, bytesReceived);
      } else {
        await _emitFailed(controller, movieId, e.toString(), partialFile);
      }
      return;
    }

    await sink.flush();
    await sink.close();

    if (isCancelled()) {
      await _emitCancelled(controller, movieId, partialFile, bytesReceived);
      return;
    }

    await partialFile.rename(finalFile.path);

    controller.add(
      MovieDownload(
        movieId: movieId,
        status: DownloadStatus.complete,
        bytesReceived: bytesReceived,
        bytesTotal: bytesTotal ?? bytesReceived,
        localPath: finalFile.path,
        updatedAt: DateTime.now(),
      ),
    );
    await controller.close();
  } catch (e) {
    controller.add(
      MovieDownload(
        movieId: movieId,
        status: DownloadStatus.failed,
        bytesReceived: 0,
        errorMessage: e.toString(),
        updatedAt: DateTime.now(),
      ),
    );
    if (!controller.isClosed) await controller.close();
  }
}

int? _resolveTotalSize(Headers headers, int initialBytes) {
  final contentRange = headers.value('content-range');
  if (contentRange != null) {
    final match = RegExp(r'/(\d+)\s*$').firstMatch(contentRange);
    if (match != null) {
      final parsed = int.tryParse(match.group(1)!);
      if (parsed != null) return parsed;
    }
  }
  final contentLength = headers.value(Headers.contentLengthHeader);
  if (contentLength != null) {
    final parsed = int.tryParse(contentLength);
    if (parsed != null) return parsed + initialBytes;
  }
  return null;
}

/// Parses the `start` byte from a `Content-Range: bytes <start>-<end>/<total>`
/// header. Returns `null` when the header is missing or malformed.
int? _parseContentRangeStart(String? contentRange) {
  if (contentRange == null) return null;
  final match = RegExp(r'bytes\s+(\d+)-').firstMatch(contentRange);
  if (match == null) return null;
  return int.tryParse(match.group(1)!);
}

bool _meetsReadyThreshold(int received, int? total) {
  if (received < _readyThresholdBytes) return false;
  if (total == null) return true;
  return received >= total * _readyThresholdFraction;
}

Future<void> _emitCancelled(
  StreamController<MovieDownload> controller,
  String movieId,
  File partialFile,
  int bytes,
) async {
  controller.add(
    MovieDownload(
      movieId: movieId,
      status: DownloadStatus.cancelled,
      bytesReceived: bytes,
      localPath: await partialFile.exists() ? partialFile.path : null,
      updatedAt: DateTime.now(),
    ),
  );
  if (!controller.isClosed) await controller.close();
}

Future<void> _emitFailed(
  StreamController<MovieDownload> controller,
  String movieId,
  String message,
  File partialFile,
) async {
  final bytes = await partialFile.exists() ? await partialFile.length() : 0;
  controller.add(
    MovieDownload(
      movieId: movieId,
      status: DownloadStatus.failed,
      bytesReceived: bytes,
      localPath: await partialFile.exists() ? partialFile.path : null,
      errorMessage: message,
      updatedAt: DateTime.now(),
    ),
  );
  if (!controller.isClosed) await controller.close();
}
