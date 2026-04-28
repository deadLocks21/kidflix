import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:kidflix/core/domain/model/movie_download.dart';
import 'package:kidflix/core/domain/services/download.repository.dart';
import 'package:kidflix/infrastructure/downloads/http_download_stream.dart';
import 'package:path_provider/path_provider.dart';

/// HTTP implementation of [DownloadRepository] backed by Dio.
///
/// Hits `GET /movies/{movie_id}/download` per `API.md` § Téléchargement
/// de fichier vidéo, with `Range` support for resume and the same on-disk
/// layout (`${documents}/downloads/{movieId}.mp4`) as
/// [InMemoryDownloadRepository]. The required `Authorization: Bearer <jwt>` and `X-Device-Id: <uuid>` headers are injected transparently
/// by the `AuthInterceptor` registered on `dioProvider` — this
/// repository never touches headers explicitly.
///
/// Errors (4xx/5xx/network) are surfaced as
/// [DownloadStatus.failed] with the dio-supplied message; no
/// metier-level Domain exception mapping. `cancel` and `delete` operate
/// on the local filesystem only — there is no documented backend
/// endpoint for either.
class DioDownloadRepository implements DownloadRepository {
  final Dio _dio;
  final Directory? _downloadsDirOverride;
  final Map<String, _ActiveDownload> _active = {};
  Directory? _cachedDir;

  DioDownloadRepository({required Dio dio, Directory? downloadsDirectory})
    : _dio = dio,
      _downloadsDirOverride = downloadsDirectory;

  @override
  Future<MovieDownload?> findByMovieId(String movieId) async {
    final active = _active[movieId];
    if (active != null && active.currentSnapshot != null) {
      return active.currentSnapshot;
    }
    final dir = await _resolveDir();
    return inspectDownloadOnDisk(movieId: movieId, downloadsDir: dir);
  }

  @override
  Stream<MovieDownload> download(String movieId) {
    final existing = _active[movieId];
    if (existing != null) return existing.controller.stream;

    final active = _ActiveDownload();
    _active[movieId] = active;
    unawaited(_runDownload(movieId, active));
    return active.controller.stream;
  }

  @override
  Future<void> cancel(String movieId) async {
    final active = _active[movieId];
    if (active == null) return;
    active.cancelled = true;
    active.cancelToken.cancel('user-cancel');
    await active.controller.done;
  }

  @override
  Future<void> delete(String movieId) async {
    await cancel(movieId);
    final dir = await _resolveDir();
    final finalFile = File('${dir.path}/$movieId.mp4');
    if (await finalFile.exists()) await finalFile.delete();
    final partialFile = File('${dir.path}/$movieId.mp4.partial');
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

  Future<void> _runDownload(String movieId, _ActiveDownload active) async {
    try {
      final dir = await _resolveDir();
      final source = streamHttpDownload(
        dio: _dio,
        url: '/movies/$movieId/download',
        movieId: movieId,
        downloadsDir: dir,
        cancelToken: active.cancelToken,
        isCancelled: () => active.cancelled,
      );
      await for (final event in source) {
        active.currentSnapshot = event;
        active.controller.add(event);
      }
    } finally {
      if (!active.controller.isClosed) await active.controller.close();
      _active.remove(movieId);
    }
  }
}

class _ActiveDownload {
  final StreamController<MovieDownload> controller =
      StreamController<MovieDownload>.broadcast();
  final CancelToken cancelToken = CancelToken();
  bool cancelled = false;
  MovieDownload? currentSnapshot;
}
