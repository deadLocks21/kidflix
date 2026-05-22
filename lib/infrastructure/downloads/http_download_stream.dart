import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:kidflix/core/domain/model/movie_download.dart';
import 'package:kidflix/infrastructure/downloads/download_file_naming.dart';

/// Shared download streaming primitive used by every [DownloadRepository]
/// implementation.
///
/// Each caller provides its own [Dio] so an in-memory repo can hit a
/// third-party URL without leaking auth headers, while a backend-bound
/// repo can hit a relative path under `dio.options.baseUrl` and rely on
/// the registered `AuthInterceptor`. The helper is the single source of
/// truth for the `.partial` → final-file rename, the 2 MiB + 3% `readyToPlay`
/// threshold, the 4 Hz progress throttling, and the `Range` resume
/// semantics. The final file's extension is derived from the response
/// `Content-Type` via [download_file_naming.dart] (e.g. `video/x-matroska`
/// → `.mkv`).
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
/// snapshot if a completed `<id>.<ext>` or an interrupted
/// `<id>.<ext>.partial` is found on disk (any known extension). Returns
/// `null` when neither exists.
///
/// Issues no HTTP request and depends on no in-process state.
Future<MovieDownload?> inspectDownloadOnDisk({
  required String movieId,
  required Directory downloadsDir,
}) async {
  final finalFile = await findCompletedMediaFile(downloadsDir, movieId);
  if (finalFile != null) {
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
  final partialFile = await findPartialMediaFile(downloadsDir, movieId);
  if (partialFile != null) {
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

    // Already completed on a previous run? Short-circuit with no HTTP.
    final existingFinal = await findCompletedMediaFile(downloadsDir, movieId);
    if (existingFinal != null) {
      final size = await existingFinal.length();
      controller.add(
        MovieDownload(
          movieId: movieId,
          status: DownloadStatus.complete,
          bytesReceived: size,
          bytesTotal: size,
          localPath: existingFinal.path,
          updatedAt: DateTime.now(),
        ),
      );
      await controller.close();
      return;
    }

    // Resume from an interrupted `.partial` when present. Its extension was
    // chosen by the run that created it, so we reuse it on an accepted range.
    final existingPartial = await findPartialMediaFile(downloadsDir, movieId);
    final resumeExt = existingPartial == null
        ? null
        : parseMediaFileName(existingPartial.uri.pathSegments.last)?.ext;
    final initialBytes = existingPartial != null
        ? await existingPartial.length()
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
        await _emitCancelled(
          controller,
          movieId,
          existingPartial,
          initialBytes,
        );
      } else {
        await _emitFailed(
          controller,
          movieId,
          e.message ?? 'Download failed',
          existingPartial,
        );
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

    // On an accepted resume keep the `.partial`'s existing extension;
    // otherwise (fresh download or restart-from-0) derive the real container
    // from the response `Content-Type` so MKV sources land as `.mkv`.
    final ext = serverAcceptedRange && resumeExt != null
        ? resumeExt
        : extensionForContentType(
            response.headers.value(Headers.contentTypeHeader),
          );
    final finalFile = File(
      '${downloadsDir.path}/${mediaFileName(movieId, ext)}',
    );
    final partialFile = File(
      '${downloadsDir.path}/${partialFileName(movieId, ext)}',
    );

    var bytesReceived = serverAcceptedRange ? initialBytes : 0;
    if (!serverAcceptedRange && existingPartial != null) {
      // Range rejected (or restart-from-0): drop the stale partial, which may
      // even carry a different extension than the one we just derived.
      await existingPartial.delete();
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
  File? partialFile,
  int bytes,
) async {
  String? path;
  if (partialFile != null && await partialFile.exists()) {
    path = partialFile.path;
  }
  controller.add(
    MovieDownload(
      movieId: movieId,
      status: DownloadStatus.cancelled,
      bytesReceived: bytes,
      localPath: path,
      updatedAt: DateTime.now(),
    ),
  );
  if (!controller.isClosed) await controller.close();
}

Future<void> _emitFailed(
  StreamController<MovieDownload> controller,
  String movieId,
  String message,
  File? partialFile,
) async {
  var bytes = 0;
  String? path;
  if (partialFile != null && await partialFile.exists()) {
    bytes = await partialFile.length();
    path = partialFile.path;
  }
  controller.add(
    MovieDownload(
      movieId: movieId,
      status: DownloadStatus.failed,
      bytesReceived: bytes,
      localPath: path,
      errorMessage: message,
      updatedAt: DateTime.now(),
    ),
  );
  if (!controller.isClosed) await controller.close();
}
