import 'package:flutter_test/flutter_test.dart';
import 'package:kidflix/core/domain/model/profile.dart';
import 'package:kidflix/infrastructure/series/in_memory.series.repository.dart';

void main() {
  group('InMemorySeriesRepository', () {
    final repo = InMemorySeriesRepository();

    test('seed exposes the Caminandes series', () {
      expect(InMemorySeriesRepository.seed, hasLength(1));
      expect(InMemorySeriesRepository.seed.single.id, 'caminandes');
    });

    test('findById returns the seeded Caminandes with full hierarchy',
        () async {
      final caminandes = await repo.findById('caminandes');
      expect(caminandes.id, 'caminandes');
      expect(caminandes.title, 'Caminandes');
      expect(caminandes.ageCategory, AgeCategory.enfant);
      // Specials + 1 regular season.
      expect(caminandes.seasons.length, 2);
      expect(caminandes.seasonsCount, 2);
      // 1 specials + 3 regular episodes.
      expect(caminandes.episodesCount, 4);
    });

    test('seeded series has Specials season 0 and a regular season 1',
        () async {
      final caminandes = await repo.findById('caminandes');
      final seasonNumbers =
          caminandes.seasons.map((s) => s.seasonNumber).toSet();
      expect(seasonNumbers, containsAll([0, 1]));
      final specials =
          caminandes.seasons.firstWhere((s) => s.seasonNumber == 0);
      expect(specials.name, 'Specials');
    });

    test('every episode carries its series id and season number', () async {
      final caminandes = await repo.findById('caminandes');
      for (final season in caminandes.seasons) {
        for (final ep in season.episodes) {
          expect(ep.seriesId, 'caminandes');
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
