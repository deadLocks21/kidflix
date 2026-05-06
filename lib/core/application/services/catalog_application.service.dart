import 'package:kidflix/core/application/dtos/catalog_item.dto.dart';
import 'package:kidflix/core/application/dtos/catalog_row.dto.dart';
import 'package:kidflix/core/application/dtos/continue_watching_item.dto.dart';
import 'package:kidflix/core/application/dtos/movie.dto.dart';
import 'package:kidflix/core/application/dtos/profile.dto.dart';
import 'package:kidflix/core/application/dtos/series.dto.dart';
import 'package:kidflix/core/application/usecases/resolve_continue_watching.usecase.dart';
import 'package:kidflix/core/domain/model/catalog_row.dart';
import 'package:kidflix/core/domain/model/media.dart';
import 'package:kidflix/core/domain/services/catalog.repository.dart';

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

  const CatalogApplicationService(
    this._repository, {
    ResolveContinueWatchingUseCase? continueWatching,
  }) : _continueWatching = continueWatching;

  static const int _recentlyAddedCap = 20;
  static const int _sagaThreshold = 2;

  static const List<CatalogRowType> _rowOrder = [
    CatalogRowType.continueWatching,
    CatalogRowType.recentlyAdded,
    CatalogRowType.favorites,
    CatalogRowType.saga,
    CatalogRowType.genre,
    CatalogRowType.neverWatched,
    CatalogRowType.downloaded,
  ];

  Future<List<CatalogRowDto>> buildHomeRowsFor(ProfileDto profile) async {
    final itemsFuture = _repository.listCatalog();
    final cwFuture = _continueWatching == null
        ? Future<List<ContinueWatchingItemDto>>.value(const [])
        : _continueWatching.execute(profile.id);
    final results = await Future.wait([itemsFuture, cwFuture]);
    final items = results[0] as List<CatalogItem>;
    final cwEntries = results[1] as List<ContinueWatchingItemDto>;

    // Saga / genre / favorites / never-watched / downloaded rows are
    // film-only at MVP (cf. add-series-viewing/design.md D-5). The
    // recently-added row mixes both via _buildRecentlyAddedRowFromAll.
    final movies = items.whereType<Movie>().toList(growable: false);

    final rowDtos = <CatalogRowDto>[];
    for (final type in _rowOrder) {
      switch (type) {
        case CatalogRowType.continueWatching:
          final dto = _buildContinueWatchingRowDto(cwEntries);
          if (dto.items.isNotEmpty) rowDtos.add(dto);
        case CatalogRowType.recentlyAdded:
          final domain = _buildRecentlyAddedRowFromAll(items);
          if (domain.items.isNotEmpty) rowDtos.add(_toDto(domain));
        case CatalogRowType.saga:
          for (final r in _buildSagaRows(movies)) {
            if (r.items.isNotEmpty) rowDtos.add(_toDto(r));
          }
        case CatalogRowType.genre:
          for (final r in _buildGenreRows(movies)) {
            if (r.items.isNotEmpty) rowDtos.add(_toDto(r));
          }
        case CatalogRowType.favorites:
          final r = _buildFavoritesRow(movies);
          if (r.items.isNotEmpty) rowDtos.add(_toDto(r));
        case CatalogRowType.neverWatched:
          final r = _buildNeverWatchedRow(movies);
          if (r.items.isNotEmpty) rowDtos.add(_toDto(r));
        case CatalogRowType.downloaded:
          final r = _buildDownloadedRow(movies);
          if (r.items.isNotEmpty) rowDtos.add(_toDto(r));
      }
    }

    return rowDtos;
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
  /// for the homepage row. The richer rendering (resume bar, episode
  /// reference label) is the UI's responsibility (cf. tasks 29.x).
  CatalogItemDto _continueWatchingToCatalogItemDto(
    ContinueWatchingItemDto entry,
  ) {
    return switch (entry) {
      MovieContinueDto() => entry.movie,
      EpisodeContinueDto() => SeriesDto.fromDomain(entry.series),
    };
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

  List<CatalogRow> _buildSagaRows(List<Movie> movies) {
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
      if (entry.value.length < _sagaThreshold) continue;
      final sorted = [...entry.value]..sort((a, b) {
        final yearCompare = (a.year ?? 0).compareTo(b.year ?? 0);
        if (yearCompare != 0) return yearCompare;
        return a.title.compareTo(b.title);
      });
      rows.add(
        CatalogRow(
          label: labelById[entry.key]!,
          type: CatalogRowType.saga,
          items: <CatalogItem>[...sorted],
        ),
      );
    }
    rows.sort((a, b) {
      final sizeCompare = b.items.length.compareTo(a.items.length);
      if (sizeCompare != 0) return sizeCompare;
      return a.label.compareTo(b.label);
    });
    return rows;
  }

  List<CatalogRow> _buildGenreRows(List<Movie> movies) {
    final byGenre = <String, List<Movie>>{};
    for (final m in movies) {
      final primary = m.primaryGenre;
      if (primary == null) continue;
      byGenre.putIfAbsent(primary, () => []).add(m);
    }
    final rows = <CatalogRow>[];
    for (final entry in byGenre.entries) {
      final sorted = [...entry.value]
        ..sort((a, b) => a.title.compareTo(b.title));
      rows.add(
        CatalogRow(
          label: entry.key,
          type: CatalogRowType.genre,
          items: <CatalogItem>[...sorted],
        ),
      );
    }
    rows.sort((a, b) => a.label.compareTo(b.label));
    return rows;
  }

  // TODO(MVP): remplacer par le vrai repository lorsque la capability
  // favorites existera (row alimentée par FavoritesRepository).
  CatalogRow _buildFavoritesRow(List<Movie> movies) {
    final slice = movies.length >= 5 ? movies.sublist(2, 5) : movies;
    return CatalogRow(
      label: 'Favoris',
      type: CatalogRowType.favorites,
      items: <CatalogItem>[...slice],
    );
  }

  // TODO(MVP): remplacer par le vrai repository lorsque la capability
  // watch-progress existera (complément inverse de continueWatching).
  CatalogRow _buildNeverWatchedRow(List<Movie> movies) {
    final slice = movies.length >= 7 ? movies.sublist(4, 7) : movies;
    return CatalogRow(
      label: 'Jamais vus',
      type: CatalogRowType.neverWatched,
      items: <CatalogItem>[...slice],
    );
  }

  // TODO(MVP): remplacer par le vrai repository lorsque la capability
  // downloads existera (row alimentée par DownloadsRepository / état local).
  CatalogRow _buildDownloadedRow(List<Movie> movies) {
    final slice = movies.length >= 4 ? movies.sublist(1, 4) : movies;
    return CatalogRow(
      label: 'Téléchargés',
      type: CatalogRowType.downloaded,
      items: <CatalogItem>[...slice],
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
