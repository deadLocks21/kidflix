import 'package:kidflix/core/application/dtos/catalog_row.dto.dart';
import 'package:kidflix/core/application/dtos/movie.dto.dart';
import 'package:kidflix/core/application/dtos/profile.dto.dart';
import 'package:kidflix/core/domain/model/catalog_row.dart';
import 'package:kidflix/core/domain/model/movie.dart';
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
/// Rows with an empty movie list are removed before projection. The row
/// display order is controlled by [_rowOrder], and dynamic row families
/// (sagas, genres) are sorted deterministically (sagas by size desc,
/// genres alphabetical asc).
class CatalogApplicationService {
  final CatalogRepository _repository;

  const CatalogApplicationService(this._repository);

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
    final movies = await _repository.listMoviesFor();

    final rows = <CatalogRow>[];
    for (final type in _rowOrder) {
      rows.addAll(_buildRowsOfType(type, movies));
    }

    return rows
        .where((r) => r.movies.isNotEmpty)
        .map(_toDto)
        .toList(growable: false);
  }

  List<CatalogRow> _buildRowsOfType(CatalogRowType type, List<Movie> movies) {
    return switch (type) {
      CatalogRowType.continueWatching => [_buildContinueWatchingRow(movies)],
      CatalogRowType.recentlyAdded => [_buildRecentlyAddedRow(movies)],
      CatalogRowType.favorites => [_buildFavoritesRow(movies)],
      CatalogRowType.saga => _buildSagaRows(movies),
      CatalogRowType.genre => _buildGenreRows(movies),
      CatalogRowType.neverWatched => [_buildNeverWatchedRow(movies)],
      CatalogRowType.downloaded => [_buildDownloadedRow(movies)],
    };
  }

  CatalogRow _buildRecentlyAddedRow(List<Movie> movies) {
    final sorted = [...movies]
      ..sort((a, b) => b.addedAt.compareTo(a.addedAt));
    return CatalogRow(
      label: 'Récemment ajoutés',
      type: CatalogRowType.recentlyAdded,
      movies: sorted.take(_recentlyAddedCap).toList(growable: false),
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
          movies: sorted,
        ),
      );
    }
    rows.sort((a, b) {
      final sizeCompare = b.movies.length.compareTo(a.movies.length);
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
          movies: sorted,
        ),
      );
    }
    rows.sort((a, b) => a.label.compareTo(b.label));
    return rows;
  }

  // TODO(MVP): remplacer par le vrai repository lorsque la capability
  // watch-progress existera (row alimentée par WatchProgressRepository).
  CatalogRow _buildContinueWatchingRow(List<Movie> movies) {
    return CatalogRow(
      label: 'Continuer à regarder',
      type: CatalogRowType.continueWatching,
      movies: movies.take(3).toList(growable: false),
    );
  }

  // TODO(MVP): remplacer par le vrai repository lorsque la capability
  // favorites existera (row alimentée par FavoritesRepository).
  CatalogRow _buildFavoritesRow(List<Movie> movies) {
    final slice = movies.length >= 5 ? movies.sublist(2, 5) : movies;
    return CatalogRow(
      label: 'Favoris',
      type: CatalogRowType.favorites,
      movies: slice.toList(growable: false),
    );
  }

  // TODO(MVP): remplacer par le vrai repository lorsque la capability
  // watch-progress existera (complément inverse de continueWatching).
  CatalogRow _buildNeverWatchedRow(List<Movie> movies) {
    final slice = movies.length >= 7 ? movies.sublist(4, 7) : movies;
    return CatalogRow(
      label: 'Jamais vus',
      type: CatalogRowType.neverWatched,
      movies: slice.toList(growable: false),
    );
  }

  // TODO(MVP): remplacer par le vrai repository lorsque la capability
  // downloads existera (row alimentée par DownloadsRepository / état local).
  CatalogRow _buildDownloadedRow(List<Movie> movies) {
    final slice = movies.length >= 4 ? movies.sublist(1, 4) : movies;
    return CatalogRow(
      label: 'Téléchargés',
      type: CatalogRowType.downloaded,
      movies: slice.toList(growable: false),
    );
  }

  CatalogRowDto _toDto(CatalogRow row) => CatalogRowDto(
    label: row.label,
    type: row.type.name,
    movies: row.movies.map(MovieDto.fromDomain).toList(growable: false),
  );
}
