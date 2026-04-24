import 'package:flutter_test/flutter_test.dart';
import 'package:kidflix/core/domain/model/profile.dart';
import 'package:kidflix/infrastructure/catalog/in_memory.catalog.repository.dart';

void main() {
  group('InMemoryCatalogRepository', () {
    final repo = InMemoryCatalogRepository();

    test('listMoviesFor(enfant) returns only enfant movies', () async {
      final movies = await repo.listMoviesFor(AgeCategory.enfant);
      expect(movies, isNotEmpty);
      expect(
        movies.every((m) => m.ageCategory == AgeCategory.enfant),
        isTrue,
      );
    });

    test('enfant bucket has at least 2 Astérix films (saga threshold)', () async {
      final movies = await repo.listMoviesFor(AgeCategory.enfant);
      final asterix = movies.where((m) => m.sagaId == 'asterix').toList();
      expect(asterix.length, greaterThanOrEqualTo(2));
    });

    test('enfant bucket has at least 3 distinct primary genres', () async {
      final movies = await repo.listMoviesFor(AgeCategory.enfant);
      final primaries =
          movies.map((m) => m.primaryGenre).whereType<String>().toSet();
      expect(primaries.length, greaterThanOrEqualTo(3));
    });

    test('each AgeCategory has at least one movie', () async {
      for (final category in AgeCategory.values) {
        final movies = await repo.listMoviesFor(category);
        expect(
          movies,
          isNotEmpty,
          reason: 'expected at least one movie for $category',
        );
      }
    });

    test('filter is strict — bebe movies are not in enfant', () async {
      final bebe = await repo.listMoviesFor(AgeCategory.bebe);
      final enfant = await repo.listMoviesFor(AgeCategory.enfant);
      final bebeIds = bebe.map((m) => m.id).toSet();
      final enfantIds = enfant.map((m) => m.id).toSet();
      expect(bebeIds.intersection(enfantIds), isEmpty);
    });
  });
}
