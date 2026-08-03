import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:kidflix/core/application/services/logger_application.service.dart';
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
///
/// ## Observability
///
/// [logger] is optional so tests and the in-memory repo can skip it, but
/// production callers should pass it: this loop is the only place that
/// sees the `Range` request, the server's answer to it, and whether any
/// byte ever arrived. Without those three facts a stuck download is
/// indistinguishable from a slow one. The emitted events are, in order:
///
/// | Event                          | Level | Says                          |
/// |--------------------------------|-------|-------------------------------|
/// | `download.http.request`        | info  | what `Range` we asked for     |
/// | `download.http.response`       | info  | how the server answered it    |
/// | `download.http.request_failed` | warn  | headers never arrived         |
/// | `download.http.first_byte`     | debug | time-to-first-byte            |
/// | `download.http.stalled`        | warn  | headers OK, zero bytes, hung  |
/// | `download.http.truncated`      | warn  | clean EOF short of the total  |
/// | `download.http.terminal`       | info  | final status + byte counts    |
Stream<MovieDownload> streamHttpDownload({
  required Dio dio,
  required String url,
  required String movieId,
  required Directory downloadsDir,
  required CancelToken cancelToken,
  required bool Function() isCancelled,
  LoggerApplicationService? logger,
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
      logger: logger,
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

/// How long to wait for the *first* byte of the body before declaring the
/// transfer stalled.
///
/// Dio's `receiveTimeout` does not cover this window. Its stream handler
/// arms the timeout timer inside the `onData` callback
/// (`response_stream_handler.dart`), so a server that returns headers and
/// then never sends a byte arms nothing: `await for` blocks forever, no
/// exception is raised, and the download sits in `downloading` until the
/// page is closed. 20 s is well past any plausible kDrive warm-up while
/// still being far below a user's patience for a frozen progress bar.
const _firstByteStallTimeout = Duration(seconds: 20);

Future<void> _runDownload({
  required StreamController<MovieDownload> controller,
  required Dio dio,
  required String url,
  required String movieId,
  required Directory downloadsDir,
  required CancelToken cancelToken,
  required bool Function() isCancelled,
  LoggerApplicationService? logger,
}) async {
  // Hoisted out of the `try` so every terminal path — including the
  // outermost catch — can report what was actually written and how big
  // the file was meant to be. A terminal event carrying a null
  // `bytesTotal` leaves the player with no bytes-to-time ratio for its
  // seek guard, which is how a dropped connection used to pin playback.
  var bytesReceived = 0;
  int? bytesTotal;
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

    final rangeHeader = 'bytes=$initialBytes-';
    unawaited(
      logger?.info(
        'download.http.request',
        attrs: {
          'content.id': movieId,
          'download.url': url,
          'download.range': rangeHeader,
          'download.has_partial': existingPartial != null,
          'download.partial_bytes': initialBytes,
          'download.partial_ext': ?resumeExt,
        },
      ),
    );

    final requestStartedAt = DateTime.now();
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
          headers: {HttpHeaders.rangeHeader: rangeHeader},
        ),
        cancelToken: cancelToken,
      );
    } on DioException catch (e) {
      final cancelled = isCancelled() || CancelToken.isCancel(e);
      // A resume whose `Range` starts at (or past) the end of a already
      // complete `.partial` is a legitimate 416 upstream, which the API
      // proxy reports as 502 — so `status_code` alone will not tell the
      // two apart. `download.range` above is what disambiguates them.
      unawaited(
        logger?.warn(
          'download.http.request_failed',
          attrs: {
            'content.id': movieId,
            'download.range': rangeHeader,
            'download.partial_bytes': initialBytes,
            'download.status_code': ?e.response?.statusCode,
            'download.dio_type': e.type.name,
            'download.cancelled': cancelled,
            'download.elapsed_ms': DateTime.now()
                .difference(requestStartedAt)
                .inMilliseconds,
          },
          error: e,
        ),
      );
      if (cancelled) {
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

    bytesReceived = serverAcceptedRange ? initialBytes : 0;
    if (!serverAcceptedRange && existingPartial != null) {
      // Range rejected (or restart-from-0): drop the stale partial, which may
      // even carry a different extension than the one we just derived.
      await existingPartial.delete();
    }
    if (!await partialFile.exists()) {
      await partialFile.create(recursive: true);
    }

    bytesTotal = _resolveTotalSize(response.headers, bytesReceived);

    // The one line that explains a stuck resume. `range_accepted: false`
    // with a large `partial_bytes` means we silently restarted from 0;
    // `range_accepted: true` with `bytes_on_disk == resolved_total` means
    // we asked for a range at EOF and will very likely receive no body.
    unawaited(
      logger?.info(
        'download.http.response',
        attrs: {
          'content.id': movieId,
          'download.range': rangeHeader,
          'download.status_code': statusCode,
          'download.content_range': ?response.headers.value('content-range'),
          'download.content_length': ?response.headers.value(
            Headers.contentLengthHeader,
          ),
          'download.content_type': ?response.headers.value(
            Headers.contentTypeHeader,
          ),
          'download.accept_ranges': ?response.headers.value('accept-ranges'),
          'download.range_accepted': serverAcceptedRange,
          'download.range_start': ?actualRangeStart,
          'download.bytes_on_disk': bytesReceived,
          'download.resolved_total': bytesTotal,
          'download.ext': ext,
          'download.ttfb_headers_ms': DateTime.now()
              .difference(requestStartedAt)
              .inMilliseconds,
        },
      ),
    );

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
    var chunkCount = 0;
    final bodyStartedAt = DateTime.now();

    // See [_firstByteStallTimeout]: nothing in dio fires when the body
    // never starts, so this is the only signal that separates "the server
    // is sending us nothing" from "the download is merely slow". Log-only
    // — the stream is left alone so this stays a pure observability
    // change.
    final stallWatchdog = Timer(_firstByteStallTimeout, () {
      unawaited(
        logger?.warn(
          'download.http.stalled',
          attrs: {
            'content.id': movieId,
            'download.range': rangeHeader,
            'download.status_code': statusCode,
            'download.content_range': ?response.headers.value('content-range'),
            'download.range_accepted': serverAcceptedRange,
            'download.bytes_on_disk': bytesReceived,
            'download.resolved_total': bytesTotal,
            'download.waited_ms': _firstByteStallTimeout.inMilliseconds,
          },
        ),
      );
    });

    try {
      await for (final chunk in response.data!.stream) {
        if (chunkCount == 0) {
          stallWatchdog.cancel();
          unawaited(
            logger?.debug(
              'download.http.first_byte',
              attrs: {
                'content.id': movieId,
                'download.ttfb_body_ms': DateTime.now()
                    .difference(bodyStartedAt)
                    .inMilliseconds,
                'download.chunk_bytes': chunk.length,
              },
            ),
          );
        }
        chunkCount++;
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
      stallWatchdog.cancel();
      await sink.flush();
      await sink.close();
      final cancelled =
          isCancelled() || (e is DioException && CancelToken.isCancel(e));
      unawaited(
        logger?.warn(
          'download.http.body_interrupted',
          attrs: {
            'content.id': movieId,
            'download.cancelled': cancelled,
            'download.chunks': chunkCount,
            'download.bytes_received': bytesReceived,
            'download.bytes_total': bytesTotal,
            'download.elapsed_ms': DateTime.now()
                .difference(bodyStartedAt)
                .inMilliseconds,
          },
          error: e,
        ),
      );
      if (cancelled) {
        await _emitCancelled(
          controller,
          movieId,
          partialFile,
          bytesReceived,
          bytesTotal: bytesTotal,
        );
      } else {
        await _emitFailed(
          controller,
          movieId,
          e.toString(),
          partialFile,
          bytesTotal: bytesTotal,
        );
      }
      return;
    }

    stallWatchdog.cancel();
    await sink.flush();
    await sink.close();

    if (isCancelled()) {
      await _emitCancelled(
        controller,
        movieId,
        partialFile,
        bytesReceived,
        bytesTotal: bytesTotal,
      );
      return;
    }

    // A clean EOF short of the announced total still gets renamed and
    // reported `complete` below — the file is then permanently truncated
    // and plays up to the cut with no error anywhere. Nothing else in the
    // pipeline notices, so say it here.
    if (bytesTotal != null && bytesReceived < bytesTotal) {
      unawaited(
        logger?.warn(
          'download.http.truncated',
          attrs: {
            'content.id': movieId,
            'download.bytes_received': bytesReceived,
            'download.bytes_total': bytesTotal,
            'download.missing_bytes': bytesTotal - bytesReceived,
            'download.chunks': chunkCount,
          },
        ),
      );
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
    unawaited(
      logger?.info(
        'download.http.terminal',
        attrs: {
          'content.id': movieId,
          'download.status': DownloadStatus.complete.name,
          'download.bytes_received': bytesReceived,
          'download.bytes_total': bytesTotal,
          'download.chunks': chunkCount,
          'download.duration_ms': DateTime.now()
              .difference(requestStartedAt)
              .inMilliseconds,
        },
      ),
    );
    await controller.close();
  } catch (e, st) {
    // Outermost net: filesystem errors (rename over a locked file, disk
    // full on flush) land here, not in the body handler above.
    unawaited(
      logger?.error(
        'download.http.terminal',
        attrs: {
          'content.id': movieId,
          'download.status': DownloadStatus.failed.name,
          'download.bytes_received': bytesReceived,
          'download.bytes_total': bytesTotal,
        },
        error: e,
        stack: st,
      ),
    );
    controller.add(
      MovieDownload(
        movieId: movieId,
        status: DownloadStatus.failed,
        bytesReceived: bytesReceived,
        bytesTotal: bytesTotal,
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

/// [bytesTotal] is `null` only when the download died before the
/// response headers were read — past that point callers pass the
/// resolved total so consumers keep a usable bytes-to-time ratio for the
/// partial file left on disk.
Future<void> _emitCancelled(
  StreamController<MovieDownload> controller,
  String movieId,
  File? partialFile,
  int bytes, {
  int? bytesTotal,
}) async {
  String? path;
  if (partialFile != null && await partialFile.exists()) {
    path = partialFile.path;
  }
  controller.add(
    MovieDownload(
      movieId: movieId,
      status: DownloadStatus.cancelled,
      bytesReceived: bytes,
      bytesTotal: bytesTotal,
      localPath: path,
      updatedAt: DateTime.now(),
    ),
  );
  if (!controller.isClosed) await controller.close();
}

/// See [_emitCancelled] for the [bytesTotal] contract.
Future<void> _emitFailed(
  StreamController<MovieDownload> controller,
  String movieId,
  String message,
  File? partialFile, {
  int? bytesTotal,
}) async {
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
      bytesTotal: bytesTotal,
      localPath: path,
      errorMessage: message,
      updatedAt: DateTime.now(),
    ),
  );
  if (!controller.isClosed) await controller.close();
}
