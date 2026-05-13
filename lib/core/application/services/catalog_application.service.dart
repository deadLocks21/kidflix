import 'dart:math';

import 'package:kidflix/core/application/dtos/catalog_item.dto.dart';
import 'package:kidflix/core/application/dtos/catalog_row.dto.dart';
import 'package:kidflix/core/application/dtos/continue_watching_card.dto.dart';
import 'package:kidflix/core/application/dtos/continue_watching_item.dto.dart';
import 'package:kidflix/core/application/dtos/movie.dto.dart';
import 'package:kidflix/core/application/dtos/profile.dto.dart';
import 'package:kidflix/core/application/dtos/series.dto.dart';
import 'package:kidflix/core/application/usecases/resolve_continue_watching.usecase.dart';
import 'package:kidflix/core/domain/model/catalog_row.dart';
import 'package:kidflix/core/domain/model/download_entry.dart';
import 'package:kidflix/core/domain/model/media.dart';
import 'package:kidflix/core/domain/model/watch_progress.dart';
import 'package:kidflix/core/domain/services/catalog.repository.dart';
import 'package:kidflix/core/domain/services/watch_progress.repository.dart';

/// Assembles the homepage's ordered list of [CatalogRow] instances for the
/// active profile.
///
/// Age-category filtering is **not** done here: it lives outside the
/// service in `DioCatalogRepository` (server-side via `X-Profile-Id` in
/// HTTP mode) or is intentionally absent in `InMemoryCatalogRepository`
/// (the seed is returned in full in dev mode). The [ProfileDto] parameter
/// is preserved on `buildHomeRowsFor` for future row-composition decisions
/// that may consume profile metadata other than the age category.
///
/// Continue Watching is fed by [ResolveContinueWatchingUseCase] when
/// supplied (production wiring) ; otherwise the row is empty.
///
/// Rows with an empty items list are removed before projection.
class CatalogApplicationService {
  final CatalogRepository _repository;
  final ResolveContinueWatchingUseCase? _continueWatching;
  final WatchProgressRepository? _watchProgress;

  /// Per-row item-count gate applied to "dynamic" rows (genres,
  /// "Jamais vus"). Online: `4` — avoids cluttering the home with
  /// barely-populated rows from a large catalog. Offline: `0` —
  /// downloads tend to be sparse and every row that *can* be shown
  /// should be (cf. offline mode design).
  final int _dynamicMinItems;

  const CatalogApplicationService(
    this._repository, {
    ResolveContinueWatchingUseCase? continueWatching,
    WatchProgressRepository? watchProgress,
    int dynamicMinItems = 4,
  })  : _continueWatching = continueWatching,
        _watchProgress = watchProgress,
        _dynamicMinItems = dynamicMinItems;

  static const int _recentlyAddedCap = 20;

  /// [shuffleSeed] keeps the row/items shuffle stable across rebuilds.
  /// Production wiring passes a session-scoped seed (cf.
  /// `homeShuffleSeedProvider`) so invalidations triggered by unrelated
  /// providers (e.g. `downloadInventoryProvider` after a new download)
  /// don't reshuffle the entire homepage. Tests omit it for the legacy
  /// non-deterministic behaviour.
  Future<List<CatalogRowDto>> buildHomeRowsFor(
    ProfileDto profile, {
    List<DownloadEntry> downloads = const [],
    int? shuffleSeed,
  }) async {
    final rng = shuffleSeed != null ? Random(shuffleSeed) : Random();
    final itemsFuture = _repository.listCatalog();
    final cwFuture = _continueWatching == null
        ? Future<List<ContinueWatchingItemDto>>.value(const [])
        : _continueWatching.execute(profile.id);
    final wpFuture = _watchProgress?.listForProfile(profile.id) ??
        Future<List<WatchProgress>>.value(const []);
    final results = await Future.wait([itemsFuture, cwFuture, wpFuture]);
    final items = results[0] as List<CatalogItem>;
    final cwEntries = results[1] as List<ContinueWatchingItemDto>;
    final progresses = results[2] as List<WatchProgress>;
    final watchedMovieIds = <String>{
      for (final p in progresses)
        if (p is MovieProgress) p.movieId,
    };

    // Saga / genre / favorites / never-watched rows are film-only at
    // MVP (cf. add-series-viewing/design.md D-5). The recently-added
    // and downloaded rows mix both: recently-added via
    // _buildRecentlyAddedRowFromAll, downloaded via the inventory.
    final movies = items.whereType<Movie>().toList(growable: false);

    final fixed = <CatalogRowDto>[];
    final cwDto = _buildContinueWatchingRowDto(cwEntries);
    if (cwDto.items.isNotEmpty) fixed.add(cwDto);
    final recently = _buildRecentlyAddedRowFromAll(items);
    if (recently.items.isNotEmpty) fixed.add(_toDto(recently));
    final favorites = _buildFavoritesRow(movies, rng);
    if (favorites.items.isNotEmpty) fixed.add(_toDto(favorites));
    final downloadedDto = _buildDownloadedRowDto(downloads, items, profile.id);
    if (downloadedDto.items.isNotEmpty) fixed.add(downloadedDto);

    final dynamicRows = <CatalogRow>[
      ..._buildGenreRows(movies, rng),
    ];
    final neverWatched = _buildNeverWatchedRow(movies, watchedMovieIds, rng);
    if (neverWatched.items.isNotEmpty) dynamicRows.add(neverWatched);
    final filteredDynamic = dynamicRows
        .where((r) => r.items.length >= _dynamicMinItems)
        .toList()
      ..shuffle(rng);

    return [
      ...fixed,
      ...filteredDynamic.map(_toDto),
    ];
  }

  List<T> _shuffled<T>(Iterable<T> items, Random rng) {
    final list = [...items];
    list.shuffle(rng);
    return list;
  }

  /// Build the Continue Watching row directly into a DTO since the CW
  /// usecase already produces application-layer entries (the Domain
  /// CatalogRow detour would loose the resume position).
  CatalogRowDto _buildContinueWatchingRowDto(
    List<ContinueWatchingItemDto> entries,
  ) {
    return CatalogRowDto(
      label: 'Continuer à regarder',
      type: CatalogRowType.continueWatching.name,
      items: entries
          .map<CatalogItemDto>(_continueWatchingToCatalogItemDto)
          .toList(growable: false),
    );
  }

  /// Project a Continue Watching entry to a [CatalogItemDto] suitable
  /// for the homepage row. Wraps the underlying `MovieDto` / `SeriesDto`
  /// in a [ContinueWatchingCardDto] carrying the resume progress so the
  /// row can overlay a progress bar on the poster.
  ///
  /// Progress for episodes is `0.0` when [ContinueWatchingState.kind]
  /// is `nextAfterCompleted` or `restart` (the pointed episode starts
  /// from zero). [ContinueWatchingState.never] is not expected on the
  /// row (the resolve usecase only emits it via the series-modal helper)
  /// — guarded with an assert for debug builds.
  CatalogItemDto _continueWatchingToCatalogItemDto(
    ContinueWatchingItemDto entry,
  ) {
    return switch (entry) {
      MovieContinueDto() => ContinueWatchingCardDto(
        inner: entry.movie,
        progress: _movieProgress(entry),
        dismissTarget: MovieDismissTarget(entry.movie.id),
      ),
      EpisodeContinueDto() => ContinueWatchingCardDto(
        inner: SeriesDto.fromDomain(entry.series),
        progress: _episodeProgress(entry),
        dismissTarget: SeriesDismissTarget(
          seriesId: entry.series.id,
          episodeIds: [
            for (final season in entry.series.seasons)
              for (final ep in season.episodes) ep.id,
          ],
        ),
      ),
    };
  }

  double _movieProgress(MovieContinueDto entry) {
    final total = entry.movie.duration.inSeconds;
    if (total <= 0) return 0.0;
    return entry.resumeSeconds / total;
  }

  double _episodeProgress(EpisodeContinueDto entry) {
    switch (entry.kind) {
      case ContinueWatchingState.inProgress:
        final total = entry.episode.duration.inSeconds;
        if (total <= 0) return 0.0;
        return entry.resumeSeconds / total;
      case ContinueWatchingState.nextAfterCompleted:
      case ContinueWatchingState.restart:
        return 0.0;
      case ContinueWatchingState.never:
        assert(false, 'never state should not appear in CW row');
        return 0.0;
    }
  }

  CatalogRow _buildRecentlyAddedRowFromAll(List<CatalogItem> items) {
    final sorted = [...items]
      ..sort((a, b) => b.addedAt.compareTo(a.addedAt));
    return CatalogRow(
      label: 'Récemment ajoutés',
      type: CatalogRowType.recentlyAdded,
      items: sorted.take(_recentlyAddedCap).toList(growable: false),
    );
  }

  List<CatalogRow> _buildSagaRows(List<Movie> movies, Random rng) {
    final bySaga = <String, List<Movie>>{};
    final labelById = <String, String>{};
    for (final m in movies) {
      if (!m.hasSaga) continue;
      final id = m.sagaId!;
      bySaga.putIfAbsent(id, () => []).add(m);
      labelById[id] = m.sagaLabel ?? id;
    }
    final rows = <CatalogRow>[];
    for (final entry in bySaga.entries) {
      rows.add(
        CatalogRow(
          label: labelById[entry.key]!,
          type: CatalogRowType.saga,
          items: <CatalogItem>[..._shuffled(entry.value, rng)],
        ),
      );
    }
    return rows;
  }

  List<CatalogRow> _buildGenreRows(List<Movie> movies, Random rng) {
    final byGenre = <String, List<Movie>>{};
    for (final m in movies) {
      final primary = m.primaryGenre;
      if (primary == null) continue;
      byGenre.putIfAbsent(primary, () => []).add(m);
    }
    final rows = <CatalogRow>[];
    for (final entry in byGenre.entries) {
      rows.add(
        CatalogRow(
          label: entry.key,
          type: CatalogRowType.genre,
          items: <CatalogItem>[..._shuffled(entry.value, rng)],
        ),
      );
    }
    return rows;
  }

  // TODO(MVP): remplacer par le vrai repository lorsque la capability
  // favorites existera (row alimentée par FavoritesRepository).
  CatalogRow _buildFavoritesRow(List<Movie> movies, Random rng) {
    final shuffled = _shuffled(movies, rng);
    final slice = shuffled.length >= 3 ? shuffled.sublist(0, 3) : shuffled;
    return CatalogRow(
      label: 'Favoris',
      type: CatalogRowType.favorites,
      items: <CatalogItem>[...slice],
    );
  }

  CatalogRow _buildNeverWatchedRow(
    List<Movie> movies,
    Set<String> watchedMovieIds,
    Random rng,
  ) {
    final unseen = movies.where((m) => !watchedMovieIds.contains(m.id));
    final shuffled = _shuffled(unseen, rng);
    return CatalogRow(
      label: 'Jamais vus',
      type: CatalogRowType.neverWatched,
      items: <CatalogItem>[...shuffled],
    );
  }

  /// Build the Téléchargés row from the active profile's actual
  /// downloaded inventory. Movie entries map 1:1 to a [MovieDto];
  /// episode entries are deduplicated by parent series and projected
  /// to a [SeriesDto]. Entries whose catalog metadata is missing
  /// (e.g. removed from the catalog after download) are skipped.
  /// Order follows the inventory's `lastPlayedAt`-desc sort done by
  /// [ListDownloadsUseCase].
  ///
  /// Profile filtering: an entry is shown when its
  /// `triggeredByProfileId` matches [activeProfileId], OR when it is
  /// null. Null means the manifest was created without a known
  /// triggerer (e.g. via the home "Télécharger" button, which doesn't
  /// capture the active profile yet) — those entries are treated as
  /// shared and visible to every profile.
  CatalogRowDto _buildDownloadedRowDto(
    List<DownloadEntry> downloads,
    List<CatalogItem> items,
    String activeProfileId,
  ) {
    final byId = <String, CatalogItem>{
      for (final it in items) it.id: it,
    };
    final seenSeriesIds = <String>{};
    final projected = <CatalogItemDto>[];
    for (final entry in downloads) {
      final trigger = entry.triggeredByProfileId;
      if (trigger != null && trigger != activeProfileId) continue;
      switch (entry.mediaKind) {
        case DownloadMediaKind.movie:
          final candidate = byId[entry.mediaId];
          if (candidate is Movie) {
            projected.add(MovieDto.fromDomain(candidate));
          }
        case DownloadMediaKind.episode:
          final seriesId = entry.parentSeriesId;
          if (seriesId == null) continue;
          if (!seenSeriesIds.add(seriesId)) continue;
          final candidate = byId[seriesId];
          if (candidate is Series) {
            projected.add(SeriesDto.fromDomain(candidate));
          }
      }
    }
    return CatalogRowDto(
      label: 'Téléchargés',
      type: CatalogRowType.downloaded.name,
      items: List.unmodifiable(projected),
    );
  }

  CatalogRowDto _toDto(CatalogRow row) => CatalogRowDto(
    label: row.label,
    type: row.type.name,
    items: row.items
        .map<CatalogItemDto>(_projectItem)
        .toList(growable: false),
  );

  CatalogItemDto _projectItem(CatalogItem item) => switch (item) {
        Movie() => MovieDto.fromDomain(item),
        Series() => SeriesDto.fromDomain(item),
      };
}
