import 'package:flutter_test/flutter_test.dart';
import 'package:kidflix/core/application/dtos/profile.dto.dart';
import 'package:kidflix/core/application/services/catalog_application.service.dart';
import 'package:kidflix/core/domain/model/media.dart';
import 'package:kidflix/core/domain/model/profile.dart';
import 'package:kidflix/core/domain/services/catalog.repository.dart';

class _FakeRepo implements CatalogRepository {
  final List<CatalogItem> _pool;

  _FakeRepo(List<CatalogItem> pool) : _pool = pool;

  @override
  Future<List<CatalogItem>> listCatalog() async => List.unmodifiable(_pool);

  @override
  Future<List<CatalogItem>> searchCatalog({required String query}) async =>
      const [];
}

Series _s({
  required String id,
  String title = 'Series',
  int seasonsCount = 2,
  int episodesCount = 10,
  int? year,
  DateTime? addedAt,
  AgeCategory ageCategory = AgeCategory.enfant,
  List<String> genres = const [],
}) =>
    Series(
      id: id,
      title: title,
      synopsis: '',
      ageCategory: ageCategory,
      genres: genres,
      director: const [],
      cast: const [],
      addedAt: addedAt ?? DateTime(2026, 1, 1),
      seasonsCount: seasonsCount,
      episodesCount: episodesCount,
      year: year,
    );

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
    test(
      'consumes the repository result without re-filtering by age category',
      () async {
        final service = CatalogApplicationService(
          _FakeRepo([
            _m(id: 'b1', ageCategory: AgeCategory.bebe, genres: ['Animation']),
            _m(id: 'e1', ageCategory: AgeCategory.enfant, genres: ['Aventure']),
          ]),
        );
        final rows = await service.buildHomeRowsFor(
          _profile(AgeCategory.enfant),
        );
        final allMovieIds =
            rows.expand((r) => r.items.map((m) => m.id)).toSet();
        // Both movies appear: the service forwards the repository's output
        // verbatim. Filtering is server-side (HTTP) or absent (in-memory).
        expect(allMovieIds, containsAll(['b1', 'e1']));
      },
    );

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
      expect(sagaRows.single.items.map((m) => m.id), ['a1', 'a2']);
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
      expect(saga.items.map((m) => m.id), ['y1', 'y2', 'y3']);
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
      expect(ra.items.length, 20);
      expect(ra.items.first.id, 'm24');
      expect(ra.items.last.id, 'm5');
    });

    test('empty rows are filtered out', () async {
      final service = CatalogApplicationService(_FakeRepo(const []));
      final rows = await service.buildHomeRowsFor(_profile(AgeCategory.enfant));
      expect(rows, isEmpty);
    });

    test('Recently added mixes movies and series', () async {
      final service = CatalogApplicationService(
        _FakeRepo([
          _m(id: 'm1', addedAt: DateTime(2026, 5, 4)),
          _s(id: 's1', addedAt: DateTime(2026, 5, 3)),
        ]),
      );
      final rows = await service.buildHomeRowsFor(_profile(AgeCategory.enfant));
      final ra = rows.firstWhere((r) => r.type == 'recentlyAdded');
      expect(ra.items.map((i) => i.id), ['m1', 's1']);
    });

    test('Genre row excludes series even when they share the genre', () async {
      final service = CatalogApplicationService(
        _FakeRepo([
          _m(id: 'm1', genres: const ['Animation']),
          _s(id: 's1', genres: const ['Animation']),
        ]),
      );
      final rows = await service.buildHomeRowsFor(_profile(AgeCategory.enfant));
      final genreRows = rows.where((r) => r.type == 'genre').toList();
      expect(genreRows, hasLength(1));
      expect(genreRows.single.label, 'Animation');
      expect(genreRows.single.items.map((i) => i.id), ['m1']);
    });

    test('Saga row excludes series even when they share a sagaId', () async {
      final service = CatalogApplicationService(
        _FakeRepo([
          _m(id: 'm1', sagaId: 'world', sagaLabel: 'World'),
          _m(id: 'm2', sagaId: 'world', sagaLabel: 'World'),
          _s(id: 's1'), // Series with no saga
        ]),
      );
      final rows = await service.buildHomeRowsFor(_profile(AgeCategory.enfant));
      final saga = rows.firstWhere((r) => r.type == 'saga');
      expect(saga.items.map((i) => i.id), containsAll(['m1', 'm2']));
      expect(saga.items.any((i) => i.id == 's1'), isFalse);
    });
  });
}
