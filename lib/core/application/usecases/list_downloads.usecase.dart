import 'dart:developer' as developer;

import 'package:kidflix/core/domain/model/download_entry.dart';
import 'package:kidflix/core/domain/model/download_inventory_record.dart';
import 'package:kidflix/core/domain/model/download_kind.dart';
import 'package:kidflix/core/domain/model/media.dart';
import 'package:kidflix/core/domain/services/catalog.repository.dart';
import 'package:kidflix/core/domain/services/download.repository.dart';
import 'package:kidflix/core/domain/services/series.repository.dart';

const String unknownVideoTitle = 'Vidéo inconnue';

/// When catalog/series lookup fails for an item, the title falls back to
/// `"Vidéo inconnue · <short id>"` so the parent has at least the file
/// id to identify it. Truncates UUIDs to the first 8 chars.
String _unknownTitleFor(String mediaId) {
  final shortId = mediaId.length > 8 ? mediaId.substring(0, 8) : mediaId;
  return '$unknownVideoTitle · $shortId';
}

/// The result of [ListDownloadsUseCase.execute]. Contains the inventory
/// partitioned by [DownloadKind] and pre-sorted for the manager UI.
class DownloadInventory {
  final List<DownloadEntry> downloads; // kind == download
  final List<DownloadEntry> cache; // kind == cache

  const DownloadInventory({
    required this.downloads,
    required this.cache,
  });

  bool get isEmpty => downloads.isEmpty && cache.isEmpty;
}

/// Builds the parent-facing inventory: scans the repository, joins each
/// record with the catalog/series metadata, sorts and partitions by
/// `kind`. Catalog/series resolution failures fall back to the
/// `"Vidéo inconnue · <short id>"` literal — the parent must always be
/// able to act on items present on disk, even when their metadata is gone.
///
/// **Catalog query is multi-profile.** Per `API.md` § Catalogue, the
/// `/catalog` endpoint returns ONLY items whose `age_category` exactly
/// matches the active profile's. The parent therefore never sees
/// kid-targeted items via a single call. The use case takes a
/// `profileIds` list at execution time and queries the catalog once
/// per profile, unioning the results. Series details are resolved
/// against the same profile that exposed the parent series in the
/// listing — guaranteeing visibility.
class ListDownloadsUseCase {
  final DownloadRepository _repository;
  final CatalogRepository _catalog;
  final SeriesRepository _series;

  const ListDownloadsUseCase({
    required DownloadRepository repository,
    required CatalogRepository catalog,
    required SeriesRepository series,
  })  : _repository = repository,
        _catalog = catalog,
        _series = series;

  /// [profileIds] is the family's profile ids — typically every profile
  /// in the current session. The empty list falls back to a single
  /// `listCatalog()` call (legacy / in-memory mode).
  Future<DownloadInventory> execute({List<String> profileIds = const []}) async {
    final inventory = await _repository.listAll();
    if (inventory.isEmpty) {
      return const DownloadInventory(downloads: [], cache: []);
    }

    final indexed = await _buildCatalogIndex(profileIds);
    final catalogIndex = indexed.itemsById;
    final seriesProfileById = indexed.profileBySeriesId;
    final seriesCache = <String, Series?>{}; // memo by seriesId

    final entries = <DownloadEntry>[];
    for (final record in inventory) {
      entries.add(
        record.isEpisode
            ? await _decorateEpisode(
                record,
                catalogIndex,
                seriesProfileById,
                seriesCache,
              )
            : _decorateMovie(record, catalogIndex),
      );
    }

    entries.sort(_byLastPlayedDescending);

    final downloads = <DownloadEntry>[];
    final cache = <DownloadEntry>[];
    for (final entry in entries) {
      if (entry.kind == DownloadKind.download) {
        downloads.add(entry);
      } else {
        cache.add(entry);
      }
    }

    return DownloadInventory(downloads: downloads, cache: cache);
  }

  /// Queries `/catalog` once per profile (or once globally when no
  /// profile id is provided) and merges the results into a single index.
  /// Per-profile failures are logged and skipped — the union is best
  /// available, never throwing.
  ///
  /// Also tracks, for each Series id seen, ONE profile id that exposed
  /// it. That profile id is used later to call
  /// [SeriesRepository.findByIdForProfile] so we can fetch the season /
  /// episode hierarchy of series above the parent's age category.
  Future<_CatalogIndex> _buildCatalogIndex(List<String> profileIds) async {
    final byId = <String, CatalogItem>{};
    final seriesProfile = <String, String>{};

    if (profileIds.isEmpty) {
      try {
        final items = await _catalog.listCatalog();
        for (final item in items) {
          byId[item.id] = item;
        }
      } catch (e) {
        developer.log(
          'list-downloads: catalog lookup failed (no profiles)',
          name: 'kidflix.downloads.list',
          level: 900,
          error: e,
        );
      }
      return _CatalogIndex(byId, seriesProfile);
    }

    for (final pid in profileIds) {
      try {
        final items = await _catalog.listCatalogForProfile(pid);
        for (final item in items) {
          byId.putIfAbsent(item.id, () => item);
          if (item is Series) {
            seriesProfile.putIfAbsent(item.id, () => pid);
          }
        }
      } catch (e) {
        developer.log(
          'list-downloads: catalog lookup failed for profile $pid',
          name: 'kidflix.downloads.list',
          level: 900,
          error: e,
        );
      }
    }
    return _CatalogIndex(byId, seriesProfile);
  }

  DownloadEntry _decorateMovie(
    DownloadInventoryRecord record,
    Map<String, CatalogItem> catalogIndex,
  ) {
    final candidate = catalogIndex[record.mediaId];
    final movie = candidate is Movie ? candidate : null;
    // Resolution priority: cached manifest fields (captured at action
    // time, age-filter immune) → catalog lookup → fallback literal.
    final title = record.cachedTitle ??
        movie?.title ??
        _unknownTitleFor(record.mediaId);
    final poster = record.cachedPosterUrl ?? movie?.posterUrl;
    return DownloadEntry(
      mediaId: record.mediaId,
      mediaKind: DownloadMediaKind.movie,
      kind: record.kind,
      bytesOnDisk: record.bytesOnDisk,
      completedAt: record.completedAt,
      lastPlayedAt: record.lastPlayedAt,
      triggeredByProfileId: record.triggeredByProfileId,
      displayTitle: title,
      displayPosterUrl: poster,
    );
  }

  Future<DownloadEntry> _decorateEpisode(
    DownloadInventoryRecord record,
    Map<String, CatalogItem> catalogIndex,
    Map<String, String> seriesProfileById,
    Map<String, Series?> seriesCache,
  ) async {
    Series? hostSeries;
    Episode? episode;

    // The catalog `listCatalog()` returns Series stripped of their
    // seasons/episodes — so we have to round-trip to `findById` for
    // each candidate series until we find the episode. With ~10 series
    // worst-case this is fine for MVP. A future optimization would
    // store `seriesId` directly in the manifest.
    for (final item in catalogIndex.values) {
      if (item is! Series) continue;
      final cached = seriesCache.containsKey(item.id)
          ? seriesCache[item.id]
          : await _safeFindSeries(item.id, seriesProfileById, seriesCache);
      if (cached == null) continue;
      for (final season in cached.seasons) {
        for (final ep in season.episodes) {
          if (ep.id == record.mediaId) {
            hostSeries = cached;
            episode = ep;
            break;
          }
        }
        if (episode != null) break;
      }
      if (episode != null) break;
    }

    final title = record.cachedTitle ??
        episode?.title ??
        _unknownTitleFor(record.mediaId);
    final poster = record.cachedPosterUrl ??
        episode?.thumbUrl ??
        hostSeries?.posterUrl;
    final parentTitle = record.cachedParentSeriesTitle ?? hostSeries?.title;
    return DownloadEntry(
      mediaId: record.mediaId,
      mediaKind: DownloadMediaKind.episode,
      kind: record.kind,
      bytesOnDisk: record.bytesOnDisk,
      completedAt: record.completedAt,
      lastPlayedAt: record.lastPlayedAt,
      triggeredByProfileId: record.triggeredByProfileId,
      displayTitle: title,
      displayPosterUrl: poster,
      parentSeriesTitle: parentTitle,
    );
  }

  Future<Series?> _safeFindSeries(
    String seriesId,
    Map<String, String> seriesProfileById,
    Map<String, Series?> seriesCache,
  ) async {
    try {
      // Prefer the profile-scoped lookup when we know which profile
      // exposes this series — this is the only way to fetch series
      // above the currently-active profile's age category.
      final pid = seriesProfileById[seriesId];
      final s = pid != null
          ? await _series.findByIdForProfile(seriesId, pid)
          : await _series.findById(seriesId);
      seriesCache[seriesId] = s;
      return s;
    } catch (e) {
      seriesCache[seriesId] = null;
      developer.log(
        'list-downloads: series lookup failed for $seriesId',
        name: 'kidflix.downloads.list',
        level: 900,
        error: e,
      );
      return null;
    }
  }

  /// Sort comparator: by `lastPlayedAt` descending (most recent on top).
  /// Items without `lastPlayedAt` go to the end, sub-sorted by
  /// `completedAt` descending, then `mediaId` ascending for stable ties.
  int _byLastPlayedDescending(DownloadEntry a, DownloadEntry b) {
    final al = a.lastPlayedAt;
    final bl = b.lastPlayedAt;
    if (al != null && bl != null) return bl.compareTo(al);
    if (al != null) return -1; // a has, b doesn't → a comes first
    if (bl != null) return 1;
    final ac = a.completedAt;
    final bc = b.completedAt;
    if (ac != null && bc != null) return bc.compareTo(ac);
    if (ac != null) return -1;
    if (bc != null) return 1;
    return a.mediaId.compareTo(b.mediaId);
  }
}

class _CatalogIndex {
  final Map<String, CatalogItem> itemsById;
  final Map<String, String> profileBySeriesId;

  _CatalogIndex(this.itemsById, this.profileBySeriesId);
}

