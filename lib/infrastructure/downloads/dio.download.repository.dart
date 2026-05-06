import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:kidflix/core/domain/model/episode_download.dart';
import 'package:kidflix/core/domain/model/movie_download.dart';
import 'package:kidflix/core/domain/services/download.repository.dart';
import 'package:kidflix/infrastructure/downloads/http_download_stream.dart';
import 'package:path_provider/path_provider.dart';

/// HTTP implementation of [DownloadRepository] backed by Dio.
///
/// Hits `GET /movies/{movie_id}/download` and
/// `GET /episodes/{episode_id}/download` per `API.md` § Téléchargement
/// de fichier vidéo, with `Range` support for resume and the same on-disk
/// layout as [InMemoryDownloadRepository]:
///
/// * `${documents}/downloads/movies/${movieId}.mp4` for movies.
/// * `${documents}/downloads/episodes/${episodeId}.mp4` for episodes.
///
/// The required `Authorization: Bearer <jwt>`, `X-Device-Id: <uuid>` and
/// `X-Profile-Id: <profile_id>` headers are injected transparently by the
/// `AuthInterceptor` registered on `dioProvider`.
///
/// Errors (4xx / 5xx / network) are surfaced as [DownloadStatus.failed]
/// with the dio-supplied message ; no metier-level Domain exception
/// mapping. The `cancel*` and `delete*` operations are filesystem-only.
class DioDownloadRepository implements DownloadRepository {
  final Dio _dio;
  final Directory? _downloadsDirOverride;
  final Map<String, _ActiveMovie> _activeMovies = {};
  final Map<String, _ActiveEpisode> _activeEpisodes = {};
  Directory? _cachedRootDir;

  DioDownloadRepository({required Dio dio, Directory? downloadsDirectory})
    : _dio = dio,
      _downloadsDirOverride = downloadsDirectory;

  // ── Movie pipeline ────────────────────────────────────────────────

  @override
  Future<MovieDownload?> findForMovie(String movieId) async {
    final active = _activeMovies[movieId];
    if (active != null && active.currentSnapshot != null) {
      return active.currentSnapshot;
    }
    final dir = await _resolveMoviesDir();
    return inspectDownloadOnDisk(movieId: movieId, downloadsDir: dir);
  }

  @override
  Stream<MovieDownload> downloadMovie(String movieId) {
    final existing = _activeMovies[movieId];
    if (existing != null) return existing.controller.stream;

    final active = _ActiveMovie();
    _activeMovies[movieId] = active;
    unawaited(_runMovieDownload(movieId, active));
    return active.controller.stream;
  }

  @override
  Future<void> cancelMovie(String movieId) async {
    final active = _activeMovies[movieId];
    if (active == null) return;
    active.cancelled = true;
    active.cancelToken.cancel('user-cancel');
    await active.controller.done;
  }

  @override
  Future<void> deleteMovie(String movieId) async {
    await cancelMovie(movieId);
    final dir = await _resolveMoviesDir();
    final finalFile = File('${dir.path}/$movieId.mp4');
    if (await finalFile.exists()) await finalFile.delete();
    final partialFile = File('${dir.path}/$movieId.mp4.partial');
    if (await partialFile.exists()) await partialFile.delete();
  }

  // ── Episode pipeline ──────────────────────────────────────────────

  @override
  Future<EpisodeDownload?> findForEpisode(String episodeId) async {
    final active = _activeEpisodes[episodeId];
    if (active != null && active.currentSnapshot != null) {
      return active.currentSnapshot;
    }
    final dir = await _resolveEpisodesDir();
    final movieEquivalent = await inspectDownloadOnDisk(
      movieId: episodeId,
      downloadsDir: dir,
    );
    return movieEquivalent == null
        ? null
        : _episodeFromMovieDownload(movieEquivalent);
  }

  @override
  Stream<EpisodeDownload> downloadEpisode(String episodeId) {
    final existing = _activeEpisodes[episodeId];
    if (existing != null) return existing.controller.stream;

    final active = _ActiveEpisode();
    _activeEpisodes[episodeId] = active;
    unawaited(_runEpisodeDownload(episodeId, active));
    return active.controller.stream;
  }

  @override
  Future<void> cancelEpisode(String episodeId) async {
    final active = _activeEpisodes[episodeId];
    if (active == null) return;
    active.cancelled = true;
    active.cancelToken.cancel('user-cancel');
    await active.controller.done;
  }

  @override
  Future<void> deleteEpisode(String episodeId) async {
    await cancelEpisode(episodeId);
    final dir = await _resolveEpisodesDir();
    final finalFile = File('${dir.path}/$episodeId.mp4');
    if (await finalFile.exists()) await finalFile.delete();
    final partialFile = File('${dir.path}/$episodeId.mp4.partial');
    if (await partialFile.exists()) await partialFile.delete();
  }

  // ── Internals ─────────────────────────────────────────────────────

  Future<Directory> _resolveRootDir() async {
    if (_downloadsDirOverride != null) {
      final dir = _downloadsDirOverride;
      if (!await dir.exists()) await dir.create(recursive: true);
      return dir;
    }
    if (_cachedRootDir != null) return _cachedRootDir!;
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/downloads');
    if (!await dir.exists()) await dir.create(recursive: true);
    _cachedRootDir = dir;
    return dir;
  }

  Future<Directory> _resolveMoviesDir() async {
    final root = await _resolveRootDir();
    final dir = Directory('${root.path}/movies');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<Directory> _resolveEpisodesDir() async {
    final root = await _resolveRootDir();
    final dir = Directory('${root.path}/episodes');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<void> _runMovieDownload(String movieId, _ActiveMovie active) async {
    try {
      final dir = await _resolveMoviesDir();
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
      _activeMovies.remove(movieId);
    }
  }

  Future<void> _runEpisodeDownload(
    String episodeId,
    _ActiveEpisode active,
  ) async {
    try {
      final dir = await _resolveEpisodesDir();
      final source = streamHttpDownload(
        dio: _dio,
        url: '/episodes/$episodeId/download',
        movieId: episodeId,
        downloadsDir: dir,
        cancelToken: active.cancelToken,
        isCancelled: () => active.cancelled,
      );
      await for (final event in source) {
        final episodeEvent = _episodeFromMovieDownload(event);
        active.currentSnapshot = episodeEvent;
        active.controller.add(episodeEvent);
      }
    } finally {
      if (!active.controller.isClosed) await active.controller.close();
      _activeEpisodes.remove(episodeId);
    }
  }

  EpisodeDownload _episodeFromMovieDownload(MovieDownload m) => EpisodeDownload(
    episodeId: m.movieId,
    status: m.status,
    bytesReceived: m.bytesReceived,
    bytesTotal: m.bytesTotal,
    localPath: m.localPath,
    errorMessage: m.errorMessage,
    updatedAt: m.updatedAt,
  );
}

class _ActiveMovie {
  final StreamController<MovieDownload> controller =
      StreamController<MovieDownload>.broadcast();
  final CancelToken cancelToken = CancelToken();
  bool cancelled = false;
  MovieDownload? currentSnapshot;
}

class _ActiveEpisode {
  final StreamController<EpisodeDownload> controller =
      StreamController<EpisodeDownload>.broadcast();
  final CancelToken cancelToken = CancelToken();
  bool cancelled = false;
  EpisodeDownload? currentSnapshot;
}
