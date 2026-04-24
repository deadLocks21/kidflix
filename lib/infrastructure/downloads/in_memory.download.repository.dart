import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:kidflix/core/domain/model/movie_download.dart';
import 'package:kidflix/core/domain/services/download.repository.dart';
import 'package:path_provider/path_provider.dart';

/// In-memory [DownloadRepository] that performs a real HTTP download to
/// the filesystem using `dio` and `path_provider`.
///
/// MVP shortcut: every `movieId` downloads from a single hard-coded URL
/// ([_stubUrl], Big Buck Bunny). When the HTTP backend lands, the URL
/// will be derived per `movieId` from `GET /download/:movieId` — the
/// contract and local-file behavior stay identical.
///
/// File layout under `${documents}/downloads/`:
/// - `${movieId}.mp4.partial` during download (resumable via `Range`).
/// - `${movieId}.mp4` after successful completion (the `.partial` is
///   renamed, never deleted).
class InMemoryDownloadRepository implements DownloadRepository {
  /// MVP: URL stub unique pour tous les films. Remplacée par l'endpoint
  /// backend en phase 2.
  ///
  /// Source : `archive.org` (Big Buck Bunny, Creative Commons). ~62 MB,
  /// MP4 H.264 720p ~10 min, `Accept-Ranges: bytes`. Redirect 302 vers
  /// un CDN régional suivi automatiquement par dio. Durée suffisante
  /// pour exercer resume dialog / seuil 90% / seek / auto-hide
  /// contrôles.
  static const String stubUrl =
      'https://archive.org/download/BigBuckBunny_124/Content/big_buck_bunny_720p_surround.mp4';

  static const int _readyThresholdBytes = 2 * 1024 * 1024;
  static const double _readyThresholdFraction = 0.03;
  static const Duration _throttleInterval = Duration(milliseconds: 250);

  final Dio _dio;
  final Directory? _downloadsDirOverride;
  final Map<String, _ActiveDownload> _active = {};
  Directory? _cachedDir;

  InMemoryDownloadRepository({Dio? dio, Directory? downloadsDirectory})
    : _dio = dio ?? Dio(),
      _downloadsDirOverride = downloadsDirectory;

  @override
  Future<MovieDownload?> findByMovieId(String movieId) async {
    final active = _active[movieId];
    if (active != null && active.currentSnapshot != null) {
      return active.currentSnapshot;
    }

    final dir = await _resolveDir();
    final finalFile = File(_finalPath(movieId, dir));
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
    final partialFile = File(_partialPath(movieId, dir));
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

  @override
  Stream<MovieDownload> download(String movieId) {
    final existing = _active[movieId];
    if (existing != null) return existing.stream;

    final controller = StreamController<MovieDownload>.broadcast();
    final active = _ActiveDownload(movieId: movieId, controller: controller);
    _active[movieId] = active;

    // Fire-and-forget: the loop drives the stream and closes it.
    unawaited(_runDownload(active));

    return controller.stream;
  }

  @override
  Future<void> cancel(String movieId) async {
    final active = _active[movieId];
    if (active == null) return;
    active.cancelled = true;
    active.cancelToken?.cancel('user-cancel');
    await active.controller.done;
  }

  @override
  Future<void> delete(String movieId) async {
    await cancel(movieId);
    final dir = await _resolveDir();
    final finalFile = File(_finalPath(movieId, dir));
    if (await finalFile.exists()) await finalFile.delete();
    final partialFile = File(_partialPath(movieId, dir));
    if (await partialFile.exists()) await partialFile.delete();
  }

  Future<Directory> _resolveDir() async {
    if (_downloadsDirOverride != null) {
      final dir = _downloadsDirOverride;
      if (!await dir.exists()) await dir.create(recursive: true);
      return dir;
    }
    if (_cachedDir != null) return _cachedDir!;
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/downloads');
    if (!await dir.exists()) await dir.create(recursive: true);
    _cachedDir = dir;
    return dir;
  }

  String _finalPath(String movieId, Directory dir) =>
      '${dir.path}/$movieId.mp4';

  String _partialPath(String movieId, Directory dir) =>
      '${dir.path}/$movieId.mp4.partial';

  Future<void> _runDownload(_ActiveDownload active) async {
    final movieId = active.movieId;
    try {
      final dir = await _resolveDir();
      final finalFile = File(_finalPath(movieId, dir));
      if (await finalFile.exists()) {
        final size = await finalFile.length();
        final snap = MovieDownload(
          movieId: movieId,
          status: DownloadStatus.complete,
          bytesReceived: size,
          bytesTotal: size,
          localPath: finalFile.path,
          updatedAt: DateTime.now(),
        );
        active.currentSnapshot = snap;
        active.controller.add(snap);
        await active.controller.close();
        _active.remove(movieId);
        return;
      }

      final partialFile = File(_partialPath(movieId, dir));
      final initialBytes = await partialFile.exists()
          ? await partialFile.length()
          : 0;

      active.cancelToken = CancelToken();
      final Response<ResponseBody> response;
      try {
        response = await _dio.get<ResponseBody>(
          stubUrl,
          options: Options(
            responseType: ResponseType.stream,
            headers: initialBytes > 0
                ? {HttpHeaders.rangeHeader: 'bytes=$initialBytes-'}
                : null,
          ),
          cancelToken: active.cancelToken,
        );
      } on DioException catch (e) {
        if (active.cancelled || CancelToken.isCancel(e)) {
          await _emitCancelled(active, partialFile, initialBytes);
        } else {
          await _emitFailed(active, e.message ?? 'Download failed', partialFile);
        }
        return;
      }

      final statusCode = response.statusCode ?? 0;
      final serverAcceptedRange = statusCode == 206;

      var bytesReceived = serverAcceptedRange ? initialBytes : 0;
      if (!serverAcceptedRange && await partialFile.exists()) {
        await partialFile.delete();
      }
      if (!await partialFile.exists()) {
        await partialFile.create(recursive: true);
      }

      final bytesTotal = _resolveTotalSize(response.headers, bytesReceived);

      final sink = partialFile.openWrite(mode: FileMode.writeOnlyAppend);

      final initialSnap = MovieDownload(
        movieId: movieId,
        status: DownloadStatus.downloading,
        bytesReceived: bytesReceived,
        bytesTotal: bytesTotal,
        updatedAt: DateTime.now(),
      );
      active.currentSnapshot = initialSnap;
      active.controller.add(initialSnap);

      var readyEmitted = false;
      var lastThrottledEmit = DateTime.now();

      try {
        await for (final chunk in response.data!.stream) {
          sink.add(chunk);
          bytesReceived += chunk.length;

          if (!readyEmitted && _meetsReadyThreshold(bytesReceived, bytesTotal)) {
            readyEmitted = true;
            final snap = MovieDownload(
              movieId: movieId,
              status: DownloadStatus.readyToPlay,
              bytesReceived: bytesReceived,
              bytesTotal: bytesTotal,
              localPath: partialFile.path,
              updatedAt: DateTime.now(),
            );
            active.currentSnapshot = snap;
            active.controller.add(snap);
            lastThrottledEmit = DateTime.now();
            continue;
          }

          final now = DateTime.now();
          if (now.difference(lastThrottledEmit) >= _throttleInterval) {
            lastThrottledEmit = now;
            final snap = MovieDownload(
              movieId: movieId,
              status: readyEmitted
                  ? DownloadStatus.readyToPlay
                  : DownloadStatus.downloading,
              bytesReceived: bytesReceived,
              bytesTotal: bytesTotal,
              localPath: readyEmitted ? partialFile.path : null,
              updatedAt: now,
            );
            active.currentSnapshot = snap;
            active.controller.add(snap);
          }
        }
      } catch (e) {
        await sink.flush();
        await sink.close();
        if (active.cancelled ||
            (e is DioException && CancelToken.isCancel(e))) {
          await _emitCancelled(active, partialFile, bytesReceived);
        } else {
          await _emitFailed(active, e.toString(), partialFile);
        }
        return;
      }

      await sink.flush();
      await sink.close();

      if (active.cancelled) {
        await _emitCancelled(active, partialFile, bytesReceived);
        return;
      }

      await partialFile.rename(finalFile.path);

      final finalSnap = MovieDownload(
        movieId: movieId,
        status: DownloadStatus.complete,
        bytesReceived: bytesReceived,
        bytesTotal: bytesTotal ?? bytesReceived,
        localPath: finalFile.path,
        updatedAt: DateTime.now(),
      );
      active.currentSnapshot = finalSnap;
      active.controller.add(finalSnap);
      await active.controller.close();
      _active.remove(movieId);
    } catch (e) {
      final snap = MovieDownload(
        movieId: movieId,
        status: DownloadStatus.failed,
        bytesReceived: active.currentSnapshot?.bytesReceived ?? 0,
        bytesTotal: active.currentSnapshot?.bytesTotal,
        errorMessage: e.toString(),
        updatedAt: DateTime.now(),
      );
      active.controller.add(snap);
      if (!active.controller.isClosed) await active.controller.close();
      _active.remove(movieId);
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

  bool _meetsReadyThreshold(int received, int? total) {
    if (received < _readyThresholdBytes) return false;
    if (total == null) return true;
    return received >= total * _readyThresholdFraction;
  }

  Future<void> _emitCancelled(
    _ActiveDownload active,
    File partialFile,
    int bytes,
  ) async {
    final snap = MovieDownload(
      movieId: active.movieId,
      status: DownloadStatus.cancelled,
      bytesReceived: bytes,
      localPath: await partialFile.exists() ? partialFile.path : null,
      updatedAt: DateTime.now(),
    );
    active.currentSnapshot = snap;
    active.controller.add(snap);
    if (!active.controller.isClosed) await active.controller.close();
    _active.remove(active.movieId);
  }

  Future<void> _emitFailed(
    _ActiveDownload active,
    String message,
    File partialFile,
  ) async {
    final bytes = await partialFile.exists() ? await partialFile.length() : 0;
    final snap = MovieDownload(
      movieId: active.movieId,
      status: DownloadStatus.failed,
      bytesReceived: bytes,
      localPath: await partialFile.exists() ? partialFile.path : null,
      errorMessage: message,
      updatedAt: DateTime.now(),
    );
    active.currentSnapshot = snap;
    active.controller.add(snap);
    if (!active.controller.isClosed) await active.controller.close();
    _active.remove(active.movieId);
  }
}

class _ActiveDownload {
  _ActiveDownload({required this.movieId, required this.controller});

  final String movieId;
  final StreamController<MovieDownload> controller;
  CancelToken? cancelToken;
  bool cancelled = false;
  MovieDownload? currentSnapshot;

  Stream<MovieDownload> get stream => controller.stream;
}
