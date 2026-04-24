import 'package:flutter_test/flutter_test.dart';
import 'package:kidflix/core/domain/model/profile.dart';
import 'package:kidflix/infrastructure/catalog/in_memory.catalog.repository.dart';

void main() {
  group('InMemoryCatalogRepository.searchMovies', () {
    final repo = InMemoryCatalogRepository();

    test('case-insensitive match on title', () async {
      final results = await repo.searchMovies(
        query: 'TOTORO',
        upToAgeCategory: AgeCategory.enfant,
      );
      expect(results.map((m) => m.id), contains('totoro'));
    });

    test('accent-insensitive match (query without accents matches title with)', () async {
      final results = await repo.searchMovies(
        query: 'asterix',
        upToAgeCategory: AgeCategory.enfant,
      );
      expect(
        results.map((m) => m.id),
        containsAll(['asterix-empire-du-milieu', 'asterix-potion-magique']),
      );
    });

    test('accent-insensitive match (query with accents matches title without)', () async {
      final results = await repo.searchMovies(
        query: 'Astérix',
        upToAgeCategory: AgeCategory.enfant,
      );
      expect(
        results.map((m) => m.id),
        containsAll(['asterix-empire-du-milieu', 'asterix-potion-magique']),
      );
    });

    test('matches on originalTitle', () async {
      final results = await repo.searchMovies(
        query: 'finding',
        upToAgeCategory: AgeCategory.enfant,
      );
      expect(results.map((m) => m.id), contains('nemo'));
    });

    test('hierarchy: enfant profile does not see ado movies', () async {
      final results = await repo.searchMovies(
        query: 'o',
        upToAgeCategory: AgeCategory.enfant,
      );
      final categories = results.map((m) => m.ageCategory).toSet();
      expect(
        categories.every((c) => c == AgeCategory.bebe || c == AgeCategory.enfant),
        isTrue,
      );
    });

    test('hierarchy: bebe profile only sees bebe matches', () async {
      final results = await repo.searchMovies(
        query: 'o',
        upToAgeCategory: AgeCategory.bebe,
      );
      expect(
        results.every((m) => m.ageCategory == AgeCategory.bebe),
        isTrue,
      );
    });

    test('hierarchy: adulte profile sees matches across all categories', () async {
      final results = await repo.searchMovies(
        query: 'o',
        upToAgeCategory: AgeCategory.adulte,
      );
      final categories = results.map((m) => m.ageCategory).toSet();
      expect(categories.length, greaterThan(1));
    });

    test('empty query returns every accessible movie (hierarchy filter only)', () async {
      final results = await repo.searchMovies(
        query: '',
        upToAgeCategory: AgeCategory.enfant,
      );
      final allowed = {AgeCategory.bebe, AgeCategory.enfant};
      expect(results.every((m) => allowed.contains(m.ageCategory)), isTrue);
      expect(results, isNotEmpty);
    });

    test('query with no match returns empty list', () async {
      final results = await repo.searchMovies(
        query: 'zzzzz-unlikely-title',
        upToAgeCategory: AgeCategory.adulte,
      );
      expect(results, isEmpty);
    });
  });
}
