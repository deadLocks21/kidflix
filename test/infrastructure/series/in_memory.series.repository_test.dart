import 'package:flutter_test/flutter_test.dart';
import 'package:kidflix/core/domain/model/profile.dart';
import 'package:kidflix/infrastructure/series/in_memory.series.repository.dart';

void main() {
  group('InMemorySeriesRepository', () {
    final repo = InMemorySeriesRepository();

    test('seed exposes the Pingu series', () {
      expect(InMemorySeriesRepository.seed, hasLength(1));
      expect(InMemorySeriesRepository.seed.single.id, 'pingu');
    });

    test('findById returns the seeded Pingu with full hierarchy', () async {
      final pingu = await repo.findById('pingu');
      expect(pingu.id, 'pingu');
      expect(pingu.title, 'Pingu');
      expect(pingu.ageCategory, AgeCategory.enfant);
      // Specials + 2 regular seasons.
      expect(pingu.seasons.length, 3);
      expect(pingu.seasonsCount, 3);
      // 2 specials + 5 + 5 regular episodes.
      expect(pingu.episodesCount, 12);
    });

    test('seeded series has Specials season 0 and regular seasons 1+2', () async {
      final pingu = await repo.findById('pingu');
      final seasonNumbers =
          pingu.seasons.map((s) => s.seasonNumber).toSet();
      expect(seasonNumbers, containsAll([0, 1, 2]));
      final specials =
          pingu.seasons.firstWhere((s) => s.seasonNumber == 0);
      expect(specials.name, 'Specials');
    });

    test('every episode carries its series id and season number', () async {
      final pingu = await repo.findById('pingu');
      for (final season in pingu.seasons) {
        for (final ep in season.episodes) {
          expect(ep.seriesId, 'pingu');
          expect(ep.seasonNumber, season.seasonNumber);
          expect(ep.ageCategory, AgeCategory.enfant);
        }
      }
    });

    test('findById on unknown id throws StateError', () async {
      await expectLater(
        repo.findById('unknown-series'),
        throwsA(isA<StateError>()),
      );
    });
  });
}
