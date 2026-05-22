import 'package:kidflix/core/domain/model/media.dart';
import 'package:kidflix/core/domain/model/profile.dart';
import 'package:kidflix/core/domain/services/catalog.repository.dart';
import 'package:kidflix/infrastructure/downloads/download_manifest_entry.dart';
import 'package:kidflix/infrastructure/downloads/manifest_store.dart';
import 'package:kidflix/shared/text_normalization.dart';

/// [CatalogRepository] backed by the download manifest, used as the
/// offline catalog source: when the device has no connectivity, the
/// home rows are reconstructed from the metadata that was snapshotted
/// at download time on every entry (cf.
/// `DownloadManifestEntry`'s cached* fields).
///
/// Scope and current limitations:
///
/// * **Completed downloads only.** Movie entries without a `completedAt`
///   (in-flight, cancelled, partials) are filtered out — the offline
///   catalog should only surface playable items. Series cards appear
///   as soon as at least one of their episodes is completed.
/// * **Age category is hard-required for safety.** Entries with a
///   missing or unparseable `cachedAgeCategory` are skipped — falling
///   back to the active profile's age would let unclassified content
///   bypass the kid filter, which is unsafe. Legacy manifests written
///   before the snapshot extension are healed by
///   [RefreshDownloadSnapshotsUseCase] running on every online home
///   load (and at bootstrap), so the gap is bridged transparently the
///   next time the device is online. Missing `cachedDurationSeconds`
///   is tolerated and falls back to zero (display-only, no safety
///   impact).
/// * **Age filter only**, mirroring the online flow where the filter
///   is server-side via `X-Profile-Id`: an entry is visible iff its
///   `cachedAgeCategory ∈ {activeProfile.ageCategory} ∪
///   activeProfile.includedLowerAgeCategories` — same opt-in rule as
///   the home `Profile.includedLowerAgeCategories` setting.
///
///   We deliberately do **not** apply a `triggeredByProfileId` filter
///   here even though we know who triggered each download: that filter
///   only makes sense for the dedicated "Téléchargés" row (assembled
///   in `CatalogApplicationService`), not for catalog visibility. The
///   typical scenario is a parent downloading a kid film from their
///   own profile (`trigger = parentId`) ; the kid profile must still
///   see it online and offline, gated solely by the age rule.
///
///   The active profile is supplied at construction time by the provider.
class ManifestBackedCatalogRepository implements CatalogRepository {
  final DownloadManifestStore _manifest;
  final Profile _activeProfile;

  const ManifestBackedCatalogRepository(this._manifest, this._activeProfile);

  @override
  Future<List<CatalogItem>> listCatalog() async {
    final records = await _manifest.listAll();
    final allowedAges = <AgeCategory>{
      _activeProfile.ageCategory,
      ..._activeProfile.includedLowerAgeCategories,
    };
    final results = <CatalogItem>[];

    // Movies.
    for (final record in records) {
      if (record.kind != ManifestEntryKind.movie) continue;
      final entry = record.entry;
      if (entry.completedAt == null) continue;
      final movie = _reconstructMovie(record.mediaId, entry);
      if (movie == null) continue;
      if (!allowedAges.contains(movie.ageCategory)) continue;
      results.add(movie);
    }

    // Series — built by joining each `series/<id>` snapshot with its
    // `episodes/<id>` snapshots (filtered by completion only). A
    // series card only appears when at least one of its downloaded
    // episodes survives the filter.
    final completedEpisodesBySeries = <String, List<DownloadManifestRecord>>{};
    for (final record in records) {
      if (record.kind != ManifestEntryKind.episode) continue;
      final entry = record.entry;
      if (entry.completedAt == null) continue;
      final seriesId = entry.cachedSeriesId;
      if (seriesId == null) continue;
      completedEpisodesBySeries.putIfAbsent(seriesId, () => []).add(record);
    }
    for (final record in records) {
      if (record.kind != ManifestEntryKind.series) continue;
      final entry = record.entry;
      final episodes = completedEpisodesBySeries[record.mediaId];
      if (episodes == null || episodes.isEmpty) continue;
      final series = _reconstructSeries(record.mediaId, entry, episodes);
      if (series == null) continue;
      if (!allowedAges.contains(series.ageCategory)) continue;
      results.add(series);
    }
    return results;
  }

  @override
  Future<List<CatalogItem>> searchCatalog({required String query}) async {
    final normalizedQuery = normalizeForSearch(query);
    if (normalizedQuery.isEmpty) return const [];
    final all = await listCatalog();
    return all
        .where((item) {
          final title = normalizeForSearch(item.title);
          final original = item.originalTitle == null
              ? ''
              : normalizeForSearch(item.originalTitle!);
          return title.contains(normalizedQuery) ||
              original.contains(normalizedQuery);
        })
        .toList(growable: false);
  }

  @override
  Future<List<CatalogItem>> listCatalogForProfile(String profileId) {
    return listCatalog();
  }

  /// Reconstructs a [Movie] from a manifest entry, or returns `null`
  /// when the snapshot lacks a parseable [AgeCategory] (hard safety
  /// requirement — cf. class header) or a title.
  ///
  /// Other missing fields fall back to safe defaults so the card still
  /// renders cleanly.
  Movie? _reconstructMovie(String id, DownloadManifestEntry entry) {
    final title = entry.cachedTitle;
    if (title == null || title.isEmpty) return null;
    final age = _parseAgeCategory(entry.cachedAgeCategory);
    if (age == null) return null;
    final durationSeconds = entry.cachedDurationSeconds ?? 0;
    final cast = [
      for (final c in entry.cachedTopCast)
        CastMember(name: c.name, role: c.role, photoUrl: c.photoUrl),
    ];
    final addedAt =
        entry.completedAt ??
        entry.lastPlayedAt ??
        DateTime.fromMillisecondsSinceEpoch(0).toUtc();
    return Movie(
      id: id,
      title: title,
      duration: Duration(seconds: durationSeconds),
      synopsis: entry.cachedSynopsis ?? '',
      ageCategory: age,
      genres: entry.cachedGenres,
      director: entry.cachedDirector,
      cast: cast,
      addedAt: addedAt,
      originalTitle: entry.cachedOriginalTitle,
      year: entry.cachedYear,
      tagline: entry.cachedTagline,
      posterUrl: entry.cachedPosterUrl,
      backdropUrl: entry.cachedBackdropUrl,
      logoUrl: entry.cachedLogoUrl,
    );
  }

  AgeCategory? _parseAgeCategory(String? raw) {
    if (raw == null) return null;
    for (final c in AgeCategory.values) {
      if (c.name == raw) return c;
    }
    return null;
  }

  /// Reconstructs a [Series] from its snapshot entry plus the list of
  /// downloaded-and-complete episode records belonging to it. Returns
  /// `null` when the series snapshot lacks the minimal fields (title,
  /// age category). The seasons tree is built from the supplied
  /// [episodeRecords], grouped by `cachedSeasonNumber` and sorted by
  /// `cachedEpisodeNumber`. Episodes missing structural fields
  /// (seasonNumber, episodeNumber, duration, ageCategory) are skipped.
  Series? _reconstructSeries(
    String seriesId,
    DownloadManifestEntry entry,
    List<DownloadManifestRecord> episodeRecords,
  ) {
    final title = entry.cachedTitle;
    if (title == null || title.isEmpty) return null;
    final age = _parseAgeCategory(entry.cachedAgeCategory);
    if (age == null) return null;

    final episodes = <Episode>[];
    for (final record in episodeRecords) {
      final ep = _reconstructEpisode(record.mediaId, seriesId, record.entry);
      if (ep != null) episodes.add(ep);
    }
    if (episodes.isEmpty) return null;
    // Group by season.
    final bySeason = <int, List<Episode>>{};
    for (final ep in episodes) {
      bySeason.putIfAbsent(ep.seasonNumber, () => []).add(ep);
    }
    final seasons = <Season>[];
    final seasonNumbers = bySeason.keys.toList()..sort();
    for (final n in seasonNumbers) {
      final eps = [...bySeason[n]!]
        ..sort((a, b) => a.episodeNumber.compareTo(b.episodeNumber));
      seasons.add(Season(seasonNumber: n, episodes: eps));
    }

    final cast = [
      for (final c in entry.cachedTopCast)
        CastMember(name: c.name, role: c.role, photoUrl: c.photoUrl),
    ];
    final addedAt =
        entry.completedAt ??
        entry.lastPlayedAt ??
        DateTime.fromMillisecondsSinceEpoch(0).toUtc();
    return Series(
      id: seriesId,
      title: title,
      originalTitle: entry.cachedOriginalTitle,
      year: entry.cachedYear,
      synopsis: entry.cachedSynopsis ?? '',
      tagline: entry.cachedTagline,
      posterUrl: entry.cachedPosterUrl,
      backdropUrl: entry.cachedBackdropUrl,
      logoUrl: entry.cachedLogoUrl,
      ageCategory: age,
      genres: entry.cachedGenres,
      director: entry.cachedDirector,
      cast: cast,
      addedAt: addedAt,
      // Snapshot counts fall back to what is actually on disk when the
      // backend numbers weren't captured.
      seasonsCount: entry.cachedSeasonsCount ?? seasons.length,
      episodesCount: entry.cachedEpisodesCount ?? episodes.length,
      seasons: seasons,
    );
  }

  Episode? _reconstructEpisode(
    String episodeId,
    String parentSeriesId,
    DownloadManifestEntry entry,
  ) {
    final seasonNumber = entry.cachedSeasonNumber;
    final episodeNumber = entry.cachedEpisodeNumber;
    final durationSeconds = entry.cachedDurationSeconds;
    final ageRaw = entry.cachedAgeCategory;
    if (seasonNumber == null) return null;
    if (episodeNumber == null) return null;
    if (durationSeconds == null) return null;
    if (ageRaw == null) return null;
    final age = _parseAgeCategory(ageRaw);
    if (age == null) return null;
    // The episode entry's cachedTitle is the display label (e.g.
    // "E5 · Real Title"). Strip any "S0E5 · " / "E5 · " prefix so the
    // detail modal renders the bare episode title — the tile builder
    // re-adds the ref. Falls back verbatim when no prefix matches.
    final rawTitle = entry.cachedTitle ?? '';
    final title = _stripEpisodePrefix(rawTitle);
    final addedAt =
        entry.completedAt ??
        entry.lastPlayedAt ??
        DateTime.fromMillisecondsSinceEpoch(0).toUtc();
    return Episode(
      id: episodeId,
      seriesId: parentSeriesId,
      seasonNumber: seasonNumber,
      episodeNumber: episodeNumber,
      title: title,
      duration: Duration(seconds: durationSeconds),
      ageCategory: age,
      addedAt: addedAt,
      originalTitle: entry.cachedOriginalTitle,
      synopsis: entry.cachedSynopsis,
      thumbUrl: entry.cachedPosterUrl,
    );
  }

  /// Strips a leading "Sn?Em · " or "Em · " ref from a stored episode
  /// title, leaving only the bare title.
  String _stripEpisodePrefix(String raw) {
    final match = RegExp(r'^(S\d+E\d+|E\d+)\s+·\s+').firstMatch(raw);
    if (match == null) return raw;
    return raw.substring(match.end);
  }
}
