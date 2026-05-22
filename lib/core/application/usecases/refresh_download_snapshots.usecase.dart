import 'package:kidflix/core/domain/model/media.dart';
import 'package:kidflix/core/domain/services/catalog.repository.dart';
import 'package:kidflix/core/domain/services/download.repository.dart';
import 'package:kidflix/core/domain/services/series.repository.dart';
import 'package:kidflix/infrastructure/downloads/download_manifest_entry.dart';
import 'package:kidflix/infrastructure/downloads/manifest_store.dart';

/// Rewrites the full snapshot on every manifest entry that lacks the
/// new (post offline-mode) fields, using the live catalog as the source
/// of truth. Self-heals legacy manifests written before the snapshot
/// extension landed.
///
/// Best-effort: any per-entry error is swallowed so a malformed catalog
/// item never poisons the whole pass. Idempotent at value level — the
/// underlying [DownloadRepository.cacheMediaMetadata] /
/// [DownloadRepository.cacheSeriesMetadata] skip the write when the
/// stored entry already matches.
///
/// Called from the home rows provider after the first successful online
/// fetch, with `unawaited` so it never blocks the UI.
class RefreshDownloadSnapshotsUseCase {
  final CatalogRepository _catalog;
  final SeriesRepository _series;
  final DownloadRepository _downloads;
  final DownloadManifestStore _manifest;

  const RefreshDownloadSnapshotsUseCase({
    required CatalogRepository catalog,
    required SeriesRepository series,
    required DownloadRepository downloads,
    required DownloadManifestStore manifest,
  }) : _catalog = catalog,
       _series = series,
       _downloads = downloads,
       _manifest = manifest;

  /// Runs the backfill pass.
  ///
  /// [profileIds] — every profile id whose catalog should be queried.
  /// The backend's `/catalog` endpoint strict-filters by the requesting
  /// profile (cf. `CatalogRepository.listCatalogForProfile`), so a film
  /// downloaded for one profile is never visible to another profile's
  /// catalog response. Iterating every profile in the session unions
  /// the responses so legacy snapshots get healed regardless of which
  /// profile triggered the download. The active profile is implicitly
  /// included by the caller.
  ///
  /// Pass an empty list to use the active profile's catalog only.
  Future<void> execute({List<String> profileIds = const []}) async {
    final List<DownloadManifestRecord> records;
    try {
      records = await _manifest.listAll();
    } catch (_) {
      return;
    }
    if (records.isEmpty) return;

    final moviesById = <String, Movie>{};
    final seriesById = <String, Series>{};
    if (profileIds.isEmpty) {
      try {
        final catalog = await _catalog.listCatalog();
        for (final m in catalog.whereType<Movie>()) {
          moviesById[m.id] = m;
        }
        for (final s in catalog.whereType<Series>()) {
          seriesById[s.id] = s;
        }
      } catch (_) {
        return;
      }
    } else {
      for (final profileId in profileIds) {
        try {
          final items = await _catalog.listCatalogForProfile(profileId);
          for (final m in items.whereType<Movie>()) {
            moviesById[m.id] = m;
          }
          for (final s in items.whereType<Series>()) {
            seriesById[s.id] = s;
          }
        } catch (_) {
          // Best-effort per profile.
        }
      }
      if (moviesById.isEmpty && seriesById.isEmpty) return;
    }

    // Refresh movie snapshots.
    for (final record in records) {
      if (record.kind != ManifestEntryKind.movie) continue;
      if (_isMovieSnapshotComplete(record.entry)) continue;
      final movie = moviesById[record.mediaId];
      if (movie == null) continue;
      try {
        await _downloads.cacheMediaMetadata(
          mediaId: movie.id,
          isEpisode: false,
          title: movie.title,
          posterUrl: movie.posterUrl,
          originalTitle: movie.originalTitle,
          year: movie.year,
          durationSeconds: movie.duration.inSeconds,
          ageCategory: movie.ageCategory.name,
          synopsis: movie.synopsis,
          tagline: movie.tagline,
          backdropUrl: movie.backdropUrl,
          logoUrl: movie.logoUrl,
          genres: movie.genres,
          director: movie.director,
          topCast: [
            for (final c in movie.cast.take(5))
              CachedCastMember(
                name: c.name,
                role: c.role,
                photoUrl: c.photoUrl,
              ),
          ],
        );
      } catch (_) {
        // Best-effort per entry.
      }
    }

    // Identify which series have at least one downloaded episode whose
    // snapshot is incomplete OR whose `series/<id>` entry is missing.
    // For each, fetch the full series via SeriesRepository and snapshot
    // it + its downloaded episodes.
    final seriesIdsToRefresh = <String>{};
    final completedEpisodesBySeries = <String, List<DownloadManifestRecord>>{};
    for (final record in records) {
      if (record.kind != ManifestEntryKind.episode) continue;
      if (record.entry.completedAt == null) continue;
      // Best-effort lookup: we may not know the seriesId from a legacy
      // entry. Skip those — they'll self-heal when the user opens the
      // series modal next time online.
      final seriesId = record.entry.cachedSeriesId;
      if (seriesId != null) {
        completedEpisodesBySeries.putIfAbsent(seriesId, () => []).add(record);
      }
      if (!_isEpisodeSnapshotComplete(record.entry)) {
        if (seriesId != null) seriesIdsToRefresh.add(seriesId);
      }
    }
    // Also refresh series whose `series/<id>` snapshot is missing OR
    // incomplete but for which we DO have downloaded episodes.
    final knownSeriesEntries = <String, DownloadManifestEntry>{
      for (final r in records)
        if (r.kind == ManifestEntryKind.series) r.mediaId: r.entry,
    };
    for (final seriesId in completedEpisodesBySeries.keys) {
      final entry = knownSeriesEntries[seriesId];
      if (entry == null || !_isSeriesSnapshotComplete(entry)) {
        seriesIdsToRefresh.add(seriesId);
      }
    }

    for (final seriesId in seriesIdsToRefresh) {
      Series? series = seriesById[seriesId];
      if (series == null || series.seasons.isEmpty) {
        try {
          series = await _series.findById(seriesId);
        } catch (_) {
          continue;
        }
      }
      try {
        await _downloads.cacheSeriesMetadata(
          seriesId: series.id,
          title: series.title,
          posterUrl: series.posterUrl,
          originalTitle: series.originalTitle,
          year: series.year,
          ageCategory: series.ageCategory.name,
          synopsis: series.synopsis,
          tagline: series.tagline,
          backdropUrl: series.backdropUrl,
          logoUrl: series.logoUrl,
          genres: series.genres,
          director: series.director,
          topCast: [
            for (final c in series.cast.take(5))
              CachedCastMember(
                name: c.name,
                role: c.role,
                photoUrl: c.photoUrl,
              ),
          ],
          seasonsCount: series.seasonsCount,
          episodesCount: series.episodesCount,
        );
      } catch (_) {
        continue;
      }
      // Refresh episode snapshots for every downloaded episode of this
      // series.
      final downloadedIds = {
        for (final r in completedEpisodesBySeries[seriesId] ?? const [])
          r.mediaId,
      };
      for (final season in series.seasons) {
        for (final ep in season.episodes) {
          if (!downloadedIds.contains(ep.id)) continue;
          final epRef = ep.seasonNumber == 0
              ? 'S0E${ep.episodeNumber}'
              : 'E${ep.episodeNumber}';
          try {
            await _downloads.cacheMediaMetadata(
              mediaId: ep.id,
              isEpisode: true,
              title: '$epRef · ${ep.title}',
              posterUrl: ep.thumbUrl,
              parentSeriesTitle: series.title,
              originalTitle: ep.originalTitle,
              durationSeconds: ep.duration.inSeconds,
              ageCategory: ep.ageCategory.name,
              synopsis: ep.synopsis,
              seriesId: ep.seriesId,
              seasonNumber: ep.seasonNumber,
              episodeNumber: ep.episodeNumber,
            );
          } catch (_) {
            continue;
          }
        }
      }
    }
  }

  bool _isMovieSnapshotComplete(DownloadManifestEntry entry) {
    return entry.cachedTitle != null &&
        entry.cachedAgeCategory != null &&
        entry.cachedDurationSeconds != null;
  }

  bool _isEpisodeSnapshotComplete(DownloadManifestEntry entry) {
    return entry.cachedTitle != null &&
        entry.cachedSeriesId != null &&
        entry.cachedSeasonNumber != null &&
        entry.cachedEpisodeNumber != null &&
        entry.cachedAgeCategory != null &&
        entry.cachedDurationSeconds != null;
  }

  bool _isSeriesSnapshotComplete(DownloadManifestEntry entry) {
    return entry.cachedTitle != null && entry.cachedAgeCategory != null;
  }
}
