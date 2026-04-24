import 'package:flutter_test/flutter_test.dart';
import 'package:kidflix/core/application/dtos/profile.dto.dart';
import 'package:kidflix/core/application/services/catalog_application.service.dart';
import 'package:kidflix/core/domain/model/movie.dart';
import 'package:kidflix/core/domain/model/profile.dart';
import 'package:kidflix/core/domain/services/catalog.repository.dart';

class _FakeRepo implements CatalogRepository {
  final List<Movie> _pool;

  _FakeRepo(this._pool);

  @override
  Future<List<Movie>> listMoviesFor(AgeCategory ageCategory) async {
    return _pool.where((m) => m.ageCategory == ageCategory).toList();
  }

  @override
  Future<List<Movie>> searchMovies({
    required String query,
    required AgeCategory upToAgeCategory,
  }) async => const [];
}

Movie _m({
  required String id,
  String title = 'M',
  AgeCategory ageCategory = AgeCategory.enfant,
  List<String> genres = const [],
  String? sagaId,
  String? sagaLabel,
  int? year,
  DateTime? addedAt,
}) {
  return Movie(
    id: id,
    title: title,
    duration: const Duration(minutes: 90),
    synopsis: '',
    ageCategory: ageCategory,
    genres: genres,
    director: const [],
    cast: const [],
    addedAt: addedAt ?? DateTime(2026, 1, 1),
    year: year,
    sagaId: sagaId,
    sagaLabel: sagaLabel,
  );
}

ProfileDto _profile(AgeCategory category) => ProfileDto(
  id: 'p1',
  name: 'Kid',
  ageCategory: category.name,
  hasPin: false,
  isMain: false,
);

void main() {
  group('CatalogApplicationService.buildHomeRowsFor', () {
    test('filters strictly by ageCategory', () async {
      final service = CatalogApplicationService(
        _FakeRepo([
          _m(id: 'b1', ageCategory: AgeCategory.bebe, genres: ['Animation']),
          _m(id: 'e1', ageCategory: AgeCategory.enfant, genres: ['Aventure']),
        ]),
      );
      final rows = await service.buildHomeRowsFor(_profile(AgeCategory.enfant));
      final allMovieIds = rows.expand((r) => r.movies.map((m) => m.id)).toSet();
      expect(allMovieIds, contains('e1'));
      expect(allMovieIds, isNot(contains('b1')));
    });

    test('saga row needs at least 2 movies with same sagaId', () async {
      final service = CatalogApplicationService(
        _FakeRepo([
          _m(
            id: 'a1',
            sagaId: 'asterix',
            sagaLabel: 'Astérix',
            genres: ['Familial'],
          ),
          _m(
            id: 'a2',
            sagaId: 'asterix',
            sagaLabel: 'Astérix',
            genres: ['Animation'],
          ),
          _m(
            id: 'solo',
            sagaId: 'harry-potter',
            sagaLabel: 'Harry Potter',
            genres: ['Fantastique'],
          ),
        ]),
      );
      final rows = await service.buildHomeRowsFor(_profile(AgeCategory.enfant));
      final sagaRows = rows.where((r) => r.type == 'saga').toList();
      expect(sagaRows.length, 1);
      expect(sagaRows.single.label, 'Astérix');
      expect(sagaRows.single.movies.map((m) => m.id), ['a1', 'a2']);
    });

    test('film appears only in its primary (first) genre row', () async {
      final service = CatalogApplicationService(
        _FakeRepo([
          _m(id: 'x', genres: const ['Familial', 'Comédie', 'Aventure']),
        ]),
      );
      final rows = await service.buildHomeRowsFor(_profile(AgeCategory.enfant));
      final genreRows = rows.where((r) => r.type == 'genre').toList();
      expect(genreRows.length, 1);
      expect(genreRows.single.label, 'Familial');
    });

    test('row display order is fixed', () async {
      final service = CatalogApplicationService(
        _FakeRepo([
          _m(
            id: 'a1',
            sagaId: 'asterix',
            sagaLabel: 'Astérix',
            genres: ['Familial'],
          ),
          _m(
            id: 'a2',
            sagaId: 'asterix',
            sagaLabel: 'Astérix',
            genres: ['Animation'],
          ),
          _m(id: 'b', genres: const ['Comédie']),
        ]),
      );
      final rows = await service.buildHomeRowsFor(_profile(AgeCategory.enfant));
      final types = rows.map((r) => r.type).toList();
      final cwIdx = types.indexOf('continueWatching');
      final raIdx = types.indexOf('recentlyAdded');
      final favIdx = types.indexOf('favorites');
      final sagaIdx = types.indexOf('saga');
      final genreIdx = types.indexOf('genre');
      expect(cwIdx, lessThan(raIdx));
      expect(raIdx, lessThan(favIdx));
      expect(favIdx, lessThan(sagaIdx));
      expect(sagaIdx, lessThan(genreIdx));
    });

    test('sagas ordered by movie count desc', () async {
      final service = CatalogApplicationService(
        _FakeRepo([
          // Pixar: 3 films
          _m(
            id: 'p1',
            sagaId: 'pixar',
            sagaLabel: 'Pixar',
            genres: ['Animation'],
          ),
          _m(
            id: 'p2',
            sagaId: 'pixar',
            sagaLabel: 'Pixar',
            genres: ['Animation'],
          ),
          _m(
            id: 'p3',
            sagaId: 'pixar',
            sagaLabel: 'Pixar',
            genres: ['Animation'],
          ),
          // Astérix: 2 films
          _m(
            id: 'a1',
            sagaId: 'asterix',
            sagaLabel: 'Astérix',
            genres: ['Familial'],
          ),
          _m(
            id: 'a2',
            sagaId: 'asterix',
            sagaLabel: 'Astérix',
            genres: ['Familial'],
          ),
        ]),
      );
      final rows = await service.buildHomeRowsFor(_profile(AgeCategory.enfant));
      final sagaLabels =
          rows.where((r) => r.type == 'saga').map((r) => r.label).toList();
      expect(sagaLabels, ['Pixar', 'Astérix']);
    });

    test('genre rows sorted alphabetically', () async {
      final service = CatalogApplicationService(
        _FakeRepo([
          _m(id: 'x1', genres: const ['Comédie']),
          _m(id: 'x2', genres: const ['Animation']),
          _m(id: 'x3', genres: const ['Aventure']),
        ]),
      );
      final rows = await service.buildHomeRowsFor(_profile(AgeCategory.enfant));
      final labels =
          rows.where((r) => r.type == 'genre').map((r) => r.label).toList();
      expect(labels, ['Animation', 'Aventure', 'Comédie']);
    });

    test('saga internal sort by year asc', () async {
      final service = CatalogApplicationService(
        _FakeRepo([
          _m(
            id: 'y2',
            year: 2012,
            sagaId: 'saga',
            sagaLabel: 'Saga',
            genres: ['Familial'],
          ),
          _m(
            id: 'y1',
            year: 2002,
            sagaId: 'saga',
            sagaLabel: 'Saga',
            genres: ['Familial'],
          ),
          _m(
            id: 'y3',
            year: 2023,
            sagaId: 'saga',
            sagaLabel: 'Saga',
            genres: ['Familial'],
          ),
        ]),
      );
      final rows = await service.buildHomeRowsFor(_profile(AgeCategory.enfant));
      final saga = rows.firstWhere((r) => r.type == 'saga');
      expect(saga.movies.map((m) => m.id), ['y1', 'y2', 'y3']);
    });

    test('recentlyAdded capped at 20 and sorted desc', () async {
      final base = DateTime(2026, 1, 1);
      final movies = [
        for (int i = 0; i < 25; i++)
          _m(
            id: 'm$i',
            genres: const ['Familial'],
            addedAt: base.add(Duration(days: i)),
          ),
      ];
      final service = CatalogApplicationService(_FakeRepo(movies));
      final rows = await service.buildHomeRowsFor(_profile(AgeCategory.enfant));
      final ra = rows.firstWhere((r) => r.type == 'recentlyAdded');
      expect(ra.movies.length, 20);
      expect(ra.movies.first.id, 'm24');
      expect(ra.movies.last.id, 'm5');
    });

    test('empty rows are filtered out', () async {
      final service = CatalogApplicationService(_FakeRepo(const []));
      final rows = await service.buildHomeRowsFor(_profile(AgeCategory.enfant));
      expect(rows, isEmpty);
    });
  });
}
