import 'package:flutter_test/flutter_test.dart';
import 'package:kidflix/core/domain/model/profile.dart';
import 'package:kidflix/infrastructure/catalog/in_memory.catalog.repository.dart';

void main() {
  group('InMemoryCatalogRepository.searchMovies', () {
    final repo = InMemoryCatalogRepository();

    test('case-insensitive match on title', () async {
      final results = await repo.searchCatalog(query: 'TOTORO');
      expect(results.map((m) => m.id), contains('totoro'));
    });

    test('accent-insensitive match (query without accents matches title with)',
        () async {
      final results = await repo.searchCatalog(query: 'asterix');
      expect(
        results.map((m) => m.id),
        containsAll(['asterix-empire-du-milieu', 'asterix-potion-magique']),
      );
    });

    test('accent-insensitive match (query with accents matches title without)',
        () async {
      final results = await repo.searchCatalog(query: 'Astérix');
      expect(
        results.map((m) => m.id),
        containsAll(['asterix-empire-du-milieu', 'asterix-potion-magique']),
      );
    });

    test('matches on originalTitle', () async {
      final results = await repo.searchCatalog(query: 'finding');
      expect(results.map((m) => m.id), contains('nemo'));
    });

    test('returns matches across all age categories (no hierarchy filter)',
        () async {
      final results = await repo.searchCatalog(query: 'o');
      final categories = results.map((m) => m.ageCategory).toSet();
      expect(
        categories.length,
        greaterThan(1),
        reason: 'in-memory mode must NOT apply an age-hierarchy filter — '
            'matches from multiple categories are expected',
      );
    });

    test('empty query returns the full seed', () async {
      final results = await repo.searchCatalog(query: '');
      expect(results, isNotEmpty);
      final categories = results.map((m) => m.ageCategory).toSet();
      expect(
        categories,
        equals(AgeCategory.values.toSet()),
        reason: 'every seeded category should be reachable',
      );
    });

    test('query with no match returns empty list', () async {
      final results =
          await repo.searchCatalog(query: 'zzzzz-unlikely-title');
      expect(results, isEmpty);
    });
  });
}
