import 'package:flutter_test/flutter_test.dart';
import 'package:kidflix/core/domain/model/profile.dart';
import 'package:kidflix/infrastructure/catalog/in_memory.catalog.repository.dart';

void main() {
  group('InMemoryCatalogRepository.searchMovies', () {
    final repo = InMemoryCatalogRepository();

    test('case-insensitive match on title', () async {
      final results = await repo.searchCatalog(query: 'SINTEL');
      expect(results.map((m) => m.id), contains('sintel'));
    });

    test('accent-insensitive match (query without accents matches title with)',
        () async {
      // "Agent 327 : Opération Barbershop" carries an accent on "é".
      final results = await repo.searchCatalog(query: 'operation');
      expect(
        results.map((m) => m.id),
        contains('agent-327-barbershop'),
      );
    });

    test('accent-insensitive match (query with accents matches title without)',
        () async {
      // Original English title "Operation Barbershop" has no accent —
      // querying with one should still match.
      final results = await repo.searchCatalog(query: 'Opération');
      expect(
        results.map((m) => m.id),
        contains('agent-327-barbershop'),
      );
    });

    test('matches on originalTitle', () async {
      final results = await repo.searchCatalog(query: 'tears');
      expect(results.map((m) => m.id), contains('tears-of-steel'));
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
