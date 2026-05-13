import 'dart:io';

import 'package:kidflix/core/domain/model/download_inventory_record.dart';
import 'package:kidflix/core/domain/model/download_kind.dart';
import 'package:kidflix/infrastructure/downloads/download_manifest_entry.dart';
import 'package:kidflix/infrastructure/downloads/manifest_store.dart';

/// Shared inventory-reading + manifest-mutation helpers, used by both
/// [InMemoryDownloadRepository] and [DioDownloadRepository] so the
/// filesystem scan / kind-flip logic exists in exactly one place.
///
/// Layout assumed:
/// * `${rootDir}/movies/<id>.mp4` and `<id>.mp4.partial` for movies.
/// * `${rootDir}/episodes/<id>.mp4` and `<id>.mp4.partial` for episodes.

/// Enumerates every download present on disk under [rootDir],
/// deduplicating per-id (`.mp4` + `.partial` for the same id appear as
/// one record with combined `bytesOnDisk`), and joins each with its
/// manifest entry. When no manifest entry exists, falls back to safe
/// defaults: `kind = cache`, `lastPlayedAt = file.lastModified`.
Future<List<DownloadInventoryRecord>> listAllDownloads({
  required Directory rootDir,
  required DownloadManifestStore manifest,
}) async {
  final results = <DownloadInventoryRecord>[];
  results.addAll(
    await _scanKind(
      kindDir: Directory('${rootDir.path}/movies'),
      isEpisode: false,
      manifest: manifest,
    ),
  );
  results.addAll(
    await _scanKind(
      kindDir: Directory('${rootDir.path}/episodes'),
      isEpisode: true,
      manifest: manifest,
    ),
  );
  return results;
}

/// Sum of `.mp4` and `.partial` file sizes under
/// `${rootDir}/{movies,episodes}/`. Returns `0` when [rootDir] is
/// absent. Never throws.
Future<int> totalBytesOnDisk(Directory rootDir) async {
  if (!await rootDir.exists()) return 0;
  var total = 0;
  for (final sub in const ['movies', 'episodes']) {
    final dir = Directory('${rootDir.path}/$sub');
    if (!await dir.exists()) continue;
    await for (final entity in dir.list(followLinks: false)) {
      if (entity is File &&
          (entity.path.endsWith('.mp4') ||
              entity.path.endsWith('.mp4.partial'))) {
        try {
          total += await entity.length();
        } catch (_) {
          // Best-effort: a transient stat error on one file should not
          // poison the total.
        }
      }
    }
  }
  return total;
}

/// Sets [kind] on the manifest entry for `(mediaId, isEpisode)`.
/// Idempotent: when the existing entry already has the same kind,
/// returns without writing. Creates a fresh entry when none exists,
/// using [mediaFileForCreate] (the on-disk `.mp4` if present) to seed
/// `lastPlayedAt` from the file's `lastModified`.
Future<void> setKind({
  required DownloadManifestStore manifest,
  required String mediaId,
  required bool isEpisode,
  required DownloadKind kind,
  File? mediaFileForCreate,
}) async {
  final existing =
      await manifest.findFor(mediaId: mediaId, isEpisode: isEpisode);
  if (existing != null) {
    if (existing.kind == kind) return;
    await manifest.upsert(
      mediaId: mediaId,
      isEpisode: isEpisode,
      entry: existing.copyWith(kind: kind),
    );
    return;
  }
  DateTime? seedLastPlayedAt;
  if (mediaFileForCreate != null && await mediaFileForCreate.exists()) {
    seedLastPlayedAt = await mediaFileForCreate.lastModified();
  }
  await manifest.upsert(
    mediaId: mediaId,
    isEpisode: isEpisode,
    entry: DownloadManifestEntry(
      kind: kind,
      lastPlayedAt: seedLastPlayedAt,
    ),
  );
}

/// Bumps `lastPlayedAt` to `now` for the given media. Creates the
/// manifest entry with `kind = cache` if absent. Other fields preserved.
Future<void> markPlayed({
  required DownloadManifestStore manifest,
  required String mediaId,
  required bool isEpisode,
  required DateTime now,
}) async {
  final existing =
      await manifest.findFor(mediaId: mediaId, isEpisode: isEpisode);
  if (existing == null) {
    await manifest.upsert(
      mediaId: mediaId,
      isEpisode: isEpisode,
      entry: DownloadManifestEntry(
        kind: DownloadKind.cache,
        lastPlayedAt: now,
      ),
    );
    return;
  }
  await manifest.upsert(
    mediaId: mediaId,
    isEpisode: isEpisode,
    entry: existing.copyWith(lastPlayedAt: now),
  );
}

/// Persists display metadata on the manifest entry for the given media.
/// Creates a fresh entry with `kind = cache` if absent. Existing entries
/// are preserved (kind, dates, triggeredByProfileId) and only the cached
/// display fields are overwritten.
///
/// Beyond the legacy `title` / `posterUrl` / `parentSeriesTitle`, accepts
/// the full snapshot fields (year, duration, age category, synopsis,
/// genres, cast, …) required to reconstruct a `MovieDetailDto` offline.
/// All snapshot fields are optional — callers pass what they hold.
Future<void> cacheMetadata({
  required DownloadManifestStore manifest,
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
  final existing =
      await manifest.findFor(mediaId: mediaId, isEpisode: isEpisode);
  if (existing == null) {
    await manifest.upsert(
      mediaId: mediaId,
      isEpisode: isEpisode,
      entry: DownloadManifestEntry(
        kind: DownloadKind.cache,
        cachedTitle: title,
        cachedPosterUrl: posterUrl,
        cachedParentSeriesTitle: parentSeriesTitle,
        cachedOriginalTitle: originalTitle,
        cachedYear: year,
        cachedDurationSeconds: durationSeconds,
        cachedAgeCategory: ageCategory,
        cachedSynopsis: synopsis,
        cachedTagline: tagline,
        cachedBackdropUrl: backdropUrl,
        cachedLogoUrl: logoUrl,
        cachedGenres: genres ?? const [],
        cachedDirector: director ?? const [],
        cachedTopCast: topCast ?? const [],
        cachedSeriesId: seriesId,
        cachedSeasonNumber: seasonNumber,
        cachedEpisodeNumber: episodeNumber,
      ),
    );
    return;
  }
  final next = existing.copyWith(
    cachedTitle: title,
    cachedPosterUrl: posterUrl,
    cachedParentSeriesTitle: parentSeriesTitle,
    cachedOriginalTitle: originalTitle,
    cachedYear: year,
    cachedDurationSeconds: durationSeconds,
    cachedAgeCategory: ageCategory,
    cachedSynopsis: synopsis,
    cachedTagline: tagline,
    cachedBackdropUrl: backdropUrl,
    cachedLogoUrl: logoUrl,
    cachedGenres: genres,
    cachedDirector: director,
    cachedTopCast: topCast,
    cachedSeriesId: seriesId,
    cachedSeasonNumber: seasonNumber,
    cachedEpisodeNumber: episodeNumber,
  );
  if (next == existing) return;
  await manifest.upsert(
    mediaId: mediaId,
    isEpisode: isEpisode,
    entry: next,
  );
}

/// Persists a full series snapshot under the dedicated `series/`
/// namespace of the manifest. Used by the series detail modal so the
/// offline catalog can rebuild the series card for any downloaded
/// episode of this series. Idempotent at value level.
Future<void> cacheSeriesSnapshot({
  required DownloadManifestStore manifest,
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
  final existing = await manifest.findForSeries(seriesId);
  if (existing == null) {
    await manifest.upsertSeries(
      seriesId,
      DownloadManifestEntry(
        kind: DownloadKind.cache,
        cachedTitle: title,
        cachedPosterUrl: posterUrl,
        cachedOriginalTitle: originalTitle,
        cachedYear: year,
        cachedAgeCategory: ageCategory,
        cachedSynopsis: synopsis,
        cachedTagline: tagline,
        cachedBackdropUrl: backdropUrl,
        cachedLogoUrl: logoUrl,
        cachedGenres: genres ?? const [],
        cachedDirector: director ?? const [],
        cachedTopCast: topCast ?? const [],
        cachedSeasonsCount: seasonsCount,
        cachedEpisodesCount: episodesCount,
      ),
    );
    return;
  }
  final next = existing.copyWith(
    cachedTitle: title,
    cachedPosterUrl: posterUrl,
    cachedOriginalTitle: originalTitle,
    cachedYear: year,
    cachedAgeCategory: ageCategory,
    cachedSynopsis: synopsis,
    cachedTagline: tagline,
    cachedBackdropUrl: backdropUrl,
    cachedLogoUrl: logoUrl,
    cachedGenres: genres,
    cachedDirector: director,
    cachedTopCast: topCast,
    cachedSeasonsCount: seasonsCount,
    cachedEpisodesCount: episodesCount,
  );
  if (next == existing) return;
  await manifest.upsertSeries(seriesId, next);
}

/// On a successful download completion, write `completedAt = now` to
/// the manifest entry, preserving the existing `kind`. Creates the
/// entry with `kind = cache` when absent (the implicit-cache default
/// for files arriving via the player).
Future<void> markCompleted({
  required DownloadManifestStore manifest,
  required String mediaId,
  required bool isEpisode,
  required DateTime now,
}) async {
  final existing =
      await manifest.findFor(mediaId: mediaId, isEpisode: isEpisode);
  if (existing == null) {
    await manifest.upsert(
      mediaId: mediaId,
      isEpisode: isEpisode,
      entry: DownloadManifestEntry(
        kind: DownloadKind.cache,
        completedAt: now,
      ),
    );
    return;
  }
  await manifest.upsert(
    mediaId: mediaId,
    isEpisode: isEpisode,
    entry: existing.copyWith(completedAt: now),
  );
}

/// Reads the current [DownloadKind] for the given media, returning
/// [DownloadKind.cache] when no manifest entry exists. Used by the
/// repository to hydrate snapshots emitted by the helper stream.
Future<DownloadKind> resolveKind({
  required DownloadManifestStore manifest,
  required String mediaId,
  required bool isEpisode,
}) async {
  final entry =
      await manifest.findFor(mediaId: mediaId, isEpisode: isEpisode);
  return entry?.kind ?? DownloadKind.cache;
}

// ── Internals ──────────────────────────────────────────────────────

Future<List<DownloadInventoryRecord>> _scanKind({
  required Directory kindDir,
  required bool isEpisode,
  required DownloadManifestStore manifest,
}) async {
  if (!await kindDir.exists()) return const [];

  // Aggregate by media id: a `.mp4` and a `.mp4.partial` for the same
  // id contribute to a single record with summed bytes.
  final byId = <String, _Aggregate>{};
  await for (final entity in kindDir.list(followLinks: false)) {
    if (entity is! File) continue;
    final fileName = entity.uri.pathSegments.last;
    String? mediaId;
    if (fileName.endsWith('.mp4.partial')) {
      mediaId = fileName.substring(0, fileName.length - '.mp4.partial'.length);
    } else if (fileName.endsWith('.mp4')) {
      mediaId = fileName.substring(0, fileName.length - '.mp4'.length);
    }
    if (mediaId == null || mediaId.isEmpty) continue;

    final agg = byId.putIfAbsent(mediaId, _Aggregate.new);
    try {
      agg.bytes += await entity.length();
      final mtime = await entity.lastModified();
      if (agg.lastModified == null || mtime.isAfter(agg.lastModified!)) {
        agg.lastModified = mtime;
      }
    } catch (_) {
      // Best-effort.
    }
  }

  final out = <DownloadInventoryRecord>[];
  for (final entry in byId.entries) {
    final mediaId = entry.key;
    final agg = entry.value;
    final manifestEntry =
        await manifest.findFor(mediaId: mediaId, isEpisode: isEpisode);
    out.add(DownloadInventoryRecord(
      mediaId: mediaId,
      isEpisode: isEpisode,
      bytesOnDisk: agg.bytes,
      kind: manifestEntry?.kind ?? DownloadKind.cache,
      completedAt: manifestEntry?.completedAt,
      lastPlayedAt: manifestEntry?.lastPlayedAt ?? agg.lastModified,
      triggeredByProfileId: manifestEntry?.triggeredByProfileId,
      cachedTitle: manifestEntry?.cachedTitle,
      cachedPosterUrl: manifestEntry?.cachedPosterUrl,
      cachedParentSeriesTitle: manifestEntry?.cachedParentSeriesTitle,
    ));
  }
  return out;
}

class _Aggregate {
  int bytes = 0;
  DateTime? lastModified;
}
