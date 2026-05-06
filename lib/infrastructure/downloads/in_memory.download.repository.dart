import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:kidflix/core/domain/model/episode_download.dart';
import 'package:kidflix/core/domain/model/movie_download.dart';
import 'package:kidflix/core/domain/services/download.repository.dart';
import 'package:kidflix/infrastructure/downloads/http_download_stream.dart';
import 'package:path_provider/path_provider.dart';

/// In-memory [DownloadRepository] for offline / dev mode (no
/// `--dart-define=API_BASE_URL`).
///
/// Delegates the HTTP streaming loop to [streamHttpDownload] and the
/// on-disk inspection to [inspectDownloadOnDisk]. The private [Dio]
/// instance has no `AuthInterceptor` registered — this is a structural
/// guarantee that no `Authorization: Bearer <jwt>` is ever sent to the
/// third-party `archive.org` URL.
///
/// MVP shortcut: every `movieId` / `episodeId` downloads from the same
/// hard-coded URL ([stubUrl], Big Buck Bunny). When the HTTP backend
/// lands, the `DioDownloadRepository` will be used instead — the
/// contract and local-file behavior stay identical.
///
/// File layout under `${documents}/downloads/`:
/// - `movies/${movieId}.mp4.partial` during download (resumable via Range).
/// - `movies/${movieId}.mp4` after successful completion.
/// - `episodes/${episodeId}.mp4.partial` / `.mp4` for the episode pipeline.
class InMemoryDownloadRepository implements DownloadRepository {
  /// MVP: URL stub unique pour tous les downloads. Remplacée par les
  /// endpoints backend en phase 2.
  ///
  /// Source : `archive.org` (Big Buck Bunny, Creative Commons). ~62 MB,
  /// MP4 H.264 720p ~10 min, `Accept-Ranges: bytes`.
  static const String stubUrl =
      'https://archive.org/download/BigBuckBunny_124/Content/big_buck_bunny_720p_surround.mp4';

  final Dio _dio;
  final Directory? _downloadsDirOverride;
  final Map<String, _ActiveMovie> _activeMovies = {};
  final Map<String, _ActiveEpisode> _activeEpisodes = {};
  Directory? _cachedRootDir;

  InMemoryDownloadRepository({Dio? dio, Directory? downloadsDirectory})
    : _dio = dio ?? Dio(),
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
        url: stubUrl,
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
        url: stubUrl,
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

  /// The shared HTTP helpers ([streamHttpDownload], [inspectDownloadOnDisk])
  /// are typed on [MovieDownload]. We re-key the snapshot into an
  /// [EpisodeDownload] here. Pure projection — no behavior change.
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
