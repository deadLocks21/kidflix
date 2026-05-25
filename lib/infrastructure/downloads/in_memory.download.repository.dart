import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:kidflix/core/domain/model/cached_cast_member.dart';
import 'package:kidflix/core/domain/model/download_inventory_record.dart';
import 'package:kidflix/core/domain/model/download_kind.dart';
import 'package:kidflix/core/domain/model/episode_download.dart';
import 'package:kidflix/core/domain/model/movie_download.dart';
import 'package:kidflix/core/domain/services/download.repository.dart';
import 'package:kidflix/infrastructure/downloads/download_file_naming.dart';
import 'package:kidflix/infrastructure/downloads/download_inventory_helper.dart'
    as inv;
import 'package:kidflix/infrastructure/downloads/http_download_stream.dart';
import 'package:kidflix/infrastructure/downloads/manifest_store.dart';
import 'package:path_provider/path_provider.dart';

/// In-memory [DownloadRepository] for offline / dev mode (no
/// `--dart-define=API_BASE_URL`).
///
/// Delegates the HTTP streaming loop to [streamHttpDownload], the
/// on-disk inspection to [inspectDownloadOnDisk], and the manifest /
/// inventory operations to [inv.listAllDownloads], [inv.totalBytesOnDisk],
/// [inv.setKind], [inv.markPlayed], [inv.markCompleted], [inv.resolveKind].
/// The private [Dio] instance has no `AuthInterceptor` registered — this
/// is a structural guarantee that no `Authorization: Bearer <jwt>` is
/// ever sent to the third-party `archive.org` URL.
///
/// MVP shortcut: every `movieId` / `episodeId` downloads from the same
/// hard-coded URL ([stubUrl], Big Buck Bunny). When the HTTP backend
/// lands, the `DioDownloadRepository` will be used instead — the
/// contract and local-file behavior stay identical.
class InMemoryDownloadRepository implements DownloadRepository {
  /// MVP: URL stub unique pour tous les downloads. Remplacée par les
  /// endpoints backend en phase 2.
  static const String stubUrl =
      'https://archive.org/download/BigBuckBunny_124/Content/big_buck_bunny_720p_surround.mp4';

  final Dio _dio;
  final Directory? _downloadsDirOverride;
  final DownloadManifestStore _manifest;
  final Map<String, _ActiveMovie> _activeMovies = {};
  final Map<String, _ActiveEpisode> _activeEpisodes = {};
  Directory? _cachedRootDir;

  InMemoryDownloadRepository({
    required DownloadManifestStore manifest,
    Dio? dio,
    Directory? downloadsDirectory,
  }) : _dio = dio ?? Dio(),
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
    final raw = await inspectDownloadOnDisk(
      movieId: movieId,
      downloadsDir: dir,
    );
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
    await deleteMediaArtifacts(dir, movieId);
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
    await deleteMediaArtifacts(dir, episodeId);
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
  Future<void> deleteAll() async {
    // Stop any in-flight stream loops before wiping the directories they
    // write into.
    for (final movieId in _activeMovies.keys.toList()) {
      await cancelMovie(movieId);
    }
    for (final episodeId in _activeEpisodes.keys.toList()) {
      await cancelEpisode(episodeId);
    }
    // Remove every artifact (completed + .partial) under both kinds; the
    // subdirectories are recreated lazily on the next download.
    final root = await _resolveRootDir();
    for (final sub in const ['movies', 'episodes']) {
      final dir = Directory('${root.path}/$sub');
      if (await dir.exists()) {
        try {
          await dir.delete(recursive: true);
        } catch (_) {
          // Best-effort, mirrors deleteMediaArtifacts.
        }
      }
    }
    // Wipe the manifest (movies + episodes + series) and reset its
    // in-memory cache so no stale entry survives.
    await _manifest.clear();
  }

  @override
  Future<void> setMovieKind(String movieId, DownloadKind kind) async {
    final dir = await _resolveMoviesDir();
    await inv.setKind(
      manifest: _manifest,
      mediaId: movieId,
      isEpisode: false,
      kind: kind,
      mediaFileForCreate: await findCompletedMediaFile(dir, movieId),
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
      mediaFileForCreate: await findCompletedMediaFile(dir, episodeId),
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
      // Hydrate kind once at session start. Mid-stream flips don't
      // re-emit (cf. spec) so a snapshot of the current kind is enough.
      final kind = await inv.resolveKind(
        manifest: _manifest,
        mediaId: movieId,
        isEpisode: false,
      );
      final source = streamHttpDownload(
        dio: _dio,
        url: stubUrl,
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
        url: stubUrl,
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
