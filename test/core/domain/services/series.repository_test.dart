import 'package:flutter_test/flutter_test.dart';
import 'package:kidflix/core/domain/model/media.dart';
import 'package:kidflix/core/domain/model/profile.dart';
import 'package:kidflix/core/domain/services/series.repository.dart';

/// Minimal fake to verify the abstract interface is correctly shaped
/// (compile-time check + smoke test).
class _FakeSeriesRepository implements SeriesRepository {
  final Map<String, Series> _byId;

  _FakeSeriesRepository(this._byId);

  @override
  Future<Series> findById(String seriesId) async {
    final hit = _byId[seriesId];
    if (hit == null) throw StateError('not found: $seriesId');
    return hit;
  }

  @override
  Future<Series> findByIdForProfile(String seriesId, String profileId) =>
      findById(seriesId);
}

Series _series(String id) => Series(
      id: id,
      title: id,
      synopsis: '',
      ageCategory: AgeCategory.enfant,
      genres: const [],
      director: const [],
      cast: const [],
      addedAt: DateTime(2026, 1, 1),
      seasonsCount: 0,
      episodesCount: 0,
      seasons: const [],
    );

void main() {
  group('SeriesRepository contract', () {
    test('any subclass exposes findById with the expected signature', () async {
      final repo = _FakeSeriesRepository({'pingu': _series('pingu')});
      final series = await repo.findById('pingu');
      expect(series.id, 'pingu');
    });

    test('findById on unknown id throws (never returns null)', () async {
      final repo = _FakeSeriesRepository({});
      await expectLater(repo.findById('unknown'), throwsA(anything));
    });
  });
}
