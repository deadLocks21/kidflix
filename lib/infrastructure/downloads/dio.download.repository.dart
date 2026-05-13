import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:kidflix/core/domain/model/cached_cast_member.dart';
import 'package:kidflix/core/domain/model/download_inventory_record.dart';
import 'package:kidflix/core/domain/model/download_kind.dart';
import 'package:kidflix/core/domain/model/episode_download.dart';
import 'package:kidflix/core/domain/model/movie_download.dart';
import 'package:kidflix/core/domain/services/download.repository.dart';
import 'package:kidflix/infrastructure/downloads/download_inventory_helper.dart'
    as inv;
import 'package:kidflix/infrastructure/downloads/http_download_stream.dart';
import 'package:kidflix/infrastructure/downloads/manifest_store.dart';
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
///
/// Inventory & manifest mutations delegate to the helpers in
/// [download_inventory_helper.dart] — the manifest is shared across
/// implementations via a singleton injected at construction time.
class DioDownloadRepository implements DownloadRepository {
  final Dio _dio;
  final DownloadManifestStore _manifest;
  final Directory? _downloadsDirOverride;
  final Map<String, _ActiveMovie> _activeMovies = {};
  final Map<String, _ActiveEpisode> _activeEpisodes = {};
  Directory? _cachedRootDir;

  DioDownloadRepository({
    required Dio dio,
    required DownloadManifestStore manifest,
    Directory? downloadsDirectory,
  })  : _dio = dio,
        _manifest = manifest,
        _downloadsDirOverride = downloadsDirectory;

  // ── Movie pipeline ────────────────────────────────────────────────

  @override
  Future<MovieDownload?> findForMovie(String movieId) async {
    final active = _activeMovies[movieId];
    if (active != null && active.currentSnapshot != null) {
      return active.currentSnapshot;
    }
    final dir = await _resolveMoviesDir();
    final raw =
        await inspectDownloadOnDisk(movieId: movieId, downloadsDir: dir);
    if (raw == null) return null;
    final kind = await inv.resolveKind(
      manifest: _manifest,
      mediaId: movieId,
      isEpisode: false,
    );
    return _withKind(raw, kind);
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
    await _manifest.remove(mediaId: movieId, isEpisode: false);
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
    if (movieEquivalent == null) return null;
    final kind = await inv.resolveKind(
      manifest: _manifest,
      mediaId: episodeId,
      isEpisode: true,
    );
    return _episodeFromMovieDownload(_withKind(movieEquivalent, kind));
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
    await _manifest.remove(mediaId: episodeId, isEpisode: true);
  }

  // ── Inventory & manifest surface ──────────────────────────────────

  @override
  Future<List<DownloadInventoryRecord>> listAll() async {
    final root = await _resolveRootDir();
    return inv.listAllDownloads(rootDir: root, manifest: _manifest);
  }

  @override
  Future<int> totalBytesOnDisk() async {
    final root = await _resolveRootDir();
    return inv.totalBytesOnDisk(root);
  }

  @override
  Future<void> setMovieKind(String movieId, DownloadKind kind) async {
    final dir = await _resolveMoviesDir();
    await inv.setKind(
      manifest: _manifest,
      mediaId: movieId,
      isEpisode: false,
      kind: kind,
      mediaFileForCreate: File('${dir.path}/$movieId.mp4'),
    );
  }

  @override
  Future<void> setEpisodeKind(String episodeId, DownloadKind kind) async {
    final dir = await _resolveEpisodesDir();
    await inv.setKind(
      manifest: _manifest,
      mediaId: episodeId,
      isEpisode: true,
      kind: kind,
      mediaFileForCreate: File('${dir.path}/$episodeId.mp4'),
    );
  }

  @override
  Future<void> markPlayed({
    required String mediaId,
    required bool isEpisode,
  }) async {
    await inv.markPlayed(
      manifest: _manifest,
      mediaId: mediaId,
      isEpisode: isEpisode,
      now: DateTime.now(),
    );
  }

  @override
  Future<void> cacheMediaMetadata({
    required String mediaId,
    required bool isEpisode,
    required String title,
    String? posterUrl,
    String? parentSeriesTitle,
    String? originalTitle,
    int? year,
    int? durationSeconds,
    String? ageCategory,
    String? synopsis,
    String? tagline,
    String? backdropUrl,
    String? logoUrl,
    List<String>? genres,
    List<String>? director,
    List<CachedCastMember>? topCast,
    String? seriesId,
    int? seasonNumber,
    int? episodeNumber,
  }) async {
    await inv.cacheMetadata(
      manifest: _manifest,
      mediaId: mediaId,
      isEpisode: isEpisode,
      title: title,
      posterUrl: posterUrl,
      parentSeriesTitle: parentSeriesTitle,
      originalTitle: originalTitle,
      year: year,
      durationSeconds: durationSeconds,
      ageCategory: ageCategory,
      synopsis: synopsis,
      tagline: tagline,
      backdropUrl: backdropUrl,
      logoUrl: logoUrl,
      genres: genres,
      director: director,
      topCast: topCast,
      seriesId: seriesId,
      seasonNumber: seasonNumber,
      episodeNumber: episodeNumber,
    );
  }

  @override
  Future<void> cacheSeriesMetadata({
    required String seriesId,
    required String title,
    String? posterUrl,
    String? originalTitle,
    int? year,
    String? ageCategory,
    String? synopsis,
    String? tagline,
    String? backdropUrl,
    String? logoUrl,
    List<String>? genres,
    List<String>? director,
    List<CachedCastMember>? topCast,
    int? seasonsCount,
    int? episodesCount,
  }) async {
    await inv.cacheSeriesSnapshot(
      manifest: _manifest,
      seriesId: seriesId,
      title: title,
      posterUrl: posterUrl,
      originalTitle: originalTitle,
      year: year,
      ageCategory: ageCategory,
      synopsis: synopsis,
      tagline: tagline,
      backdropUrl: backdropUrl,
      logoUrl: logoUrl,
      genres: genres,
      director: director,
      topCast: topCast,
      seasonsCount: seasonsCount,
      episodesCount: episodesCount,
    );
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
      final kind = await inv.resolveKind(
        manifest: _manifest,
        mediaId: movieId,
        isEpisode: false,
      );
      final source = streamHttpDownload(
        dio: _dio,
        url: '/movies/$movieId/download',
        movieId: movieId,
        downloadsDir: dir,
        cancelToken: active.cancelToken,
        isCancelled: () => active.cancelled,
      );
      await for (final raw in source) {
        final event = _withKind(raw, kind);
        if (event.status == DownloadStatus.complete) {
          await inv.markCompleted(
            manifest: _manifest,
            mediaId: movieId,
            isEpisode: false,
            now: DateTime.now(),
          );
        }
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
      final kind = await inv.resolveKind(
        manifest: _manifest,
        mediaId: episodeId,
        isEpisode: true,
      );
      final source = streamHttpDownload(
        dio: _dio,
        url: '/episodes/$episodeId/download',
        movieId: episodeId,
        downloadsDir: dir,
        cancelToken: active.cancelToken,
        isCancelled: () => active.cancelled,
      );
      await for (final raw in source) {
        final movieView = _withKind(raw, kind);
        if (movieView.status == DownloadStatus.complete) {
          await inv.markCompleted(
            manifest: _manifest,
            mediaId: episodeId,
            isEpisode: true,
            now: DateTime.now(),
          );
        }
        final episodeEvent = _episodeFromMovieDownload(movieView);
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
        kind: m.kind,
      );

  MovieDownload _withKind(MovieDownload m, DownloadKind kind) => MovieDownload(
        movieId: m.movieId,
        status: m.status,
        bytesReceived: m.bytesReceived,
        bytesTotal: m.bytesTotal,
        localPath: m.localPath,
        errorMessage: m.errorMessage,
        updatedAt: m.updatedAt,
        kind: kind,
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
