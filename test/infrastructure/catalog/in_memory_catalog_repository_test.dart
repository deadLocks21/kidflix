import 'package:flutter_test/flutter_test.dart';
import 'package:kidflix/core/domain/model/media.dart';
import 'package:kidflix/core/domain/model/profile.dart';
import 'package:kidflix/infrastructure/catalog/in_memory.catalog.repository.dart';

void main() {
  group('InMemoryCatalogRepository', () {
    final repo = InMemoryCatalogRepository();

    test('listCatalog returns the full seed regardless of any active profile',
        () async {
      final movies = await repo.listCatalog();
      expect(movies, isNotEmpty);
      // All five categories represented in the unfiltered output.
      final categories = movies.map((m) => m.ageCategory).toSet();
      expect(categories, equals(AgeCategory.values.toSet()));
    });

    test('seed contains at least 2 Stylo 2D films (saga threshold)', () async {
      final movies = await repo.listCatalog();
      final styloShorts =
          movies.where((m) => m.sagaId == 'stylo-2d').toList();
      expect(styloShorts.length, greaterThanOrEqualTo(2));
    });

    test('enfant bucket has at least 3 distinct primary genres', () async {
      final movies = await repo.listCatalog();
      final enfant = movies
          .whereType<Movie>()
          .where((m) => m.ageCategory == AgeCategory.enfant)
          .toList();
      final primaries =
          enfant.map((m) => m.primaryGenre).whereType<String>().toSet();
      expect(primaries.length, greaterThanOrEqualTo(3));
    });

    test('each AgeCategory has at least one movie in the seed', () async {
      final movies = await repo.listCatalog();
      for (final category in AgeCategory.values) {
        expect(
          movies.any((m) => m.ageCategory == category),
          isTrue,
          reason: 'expected at least one movie for $category',
        );
      }
    });
  });
}
