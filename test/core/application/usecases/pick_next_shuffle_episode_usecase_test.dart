import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:kidflix/core/application/usecases/pick_next_shuffle_episode.usecase.dart';
import 'package:kidflix/core/application/usecases/resolve_continue_watching.usecase.dart';
import 'package:kidflix/core/domain/model/media.dart';
import 'package:kidflix/core/domain/model/profile.dart';

Episode _ep({
  required String id,
  required int seasonNumber,
  required int episodeNumber,
  String seriesId = 's1',
}) =>
    Episode(
      id: id,
      seriesId: seriesId,
      seasonNumber: seasonNumber,
      episodeNumber: episodeNumber,
      title: id,
      duration: const Duration(minutes: 5),
      ageCategory: AgeCategory.enfant,
      addedAt: DateTime(2026, 5, 1),
    );

Series _series({required List<Season> seasons}) => Series(
      id: 's1',
      title: 'S',
      synopsis: '',
      ageCategory: AgeCategory.enfant,
      genres: const [],
      director: const [],
      cast: const [],
      addedAt: DateTime(2026, 5, 1),
      seasonsCount: seasons.length,
      episodesCount: seasons.fold(0, (a, s) => a + s.episodes.length),
      seasons: seasons,
    );

void main() {
  group('pickNextShuffleEpisode', () {
    final s1e1 = _ep(id: 's1e1', seasonNumber: 1, episodeNumber: 1);
    final s1e2 = _ep(id: 's1e2', seasonNumber: 1, episodeNumber: 2);
    final s2e1 = _ep(id: 's2e1', seasonNumber: 2, episodeNumber: 1);
    final s0e1 = _ep(id: 's0e1', seasonNumber: 0, episodeNumber: 1);
    final series = _series(seasons: [
      Season(seasonNumber: 1, episodes: [s1e1, s1e2]),
      Season(seasonNumber: 2, episodes: [s2e1]),
      Season(seasonNumber: 0, episodes: [s0e1]),
    ]);

    test('excludes Specials and already-played episodes', () {
      final pick = pickNextShuffleEpisode(
        series: series,
        alreadyPlayedIds: {s1e1.id, s1e2.id},
        random: Random(0),
      );
      expect(pick?.id, s2e1.id);
    });

    test('returns null when the series has no rotation episodes', () {
      final specialsOnly = _series(seasons: [
        Season(seasonNumber: 0, episodes: [s0e1]),
      ]);
      final pick = pickNextShuffleEpisode(
        series: specialsOnly,
        alreadyPlayedIds: const {},
        random: Random(0),
      );
      expect(pick, isNull);
    });

    test('resets pool when every rotation episode has been played', () {
      final pick = pickNextShuffleEpisode(
        series: series,
        alreadyPlayedIds: {s1e1.id, s1e2.id, s2e1.id},
        currentEpisodeId: s2e1.id,
        random: Random(0),
      );
      expect(pick, isNotNull);
      expect(pick!.id, isNot(s2e1.id),
          reason: 'avoids replaying the just-finished episode after reset');
    });

    test(
        'after reset, returns the only remaining episode even if it is the current',
        () {
      final single = _series(seasons: [
        Season(seasonNumber: 1, episodes: [s1e1]),
      ]);
      final pick = pickNextShuffleEpisode(
        series: single,
        alreadyPlayedIds: {s1e1.id},
        currentEpisodeId: s1e1.id,
        random: Random(0),
      );
      expect(pick?.id, s1e1.id);
    });

    test('flatRotationEpisodes orders by season then episode and skips S0',
        () {
      final episodes = flatRotationEpisodes(series);
      expect(episodes.map((e) => e.id), [s1e1.id, s1e2.id, s2e1.id]);
    });

    test('findPreviousEpisode walks back across seasons, skipping S0', () {
      expect(findPreviousEpisode(series, before: s2e1)?.id, s1e2.id);
      expect(findPreviousEpisode(series, before: s1e2)?.id, s1e1.id);
      expect(findPreviousEpisode(series, before: s1e1), isNull);
      expect(findPreviousEpisode(series, before: s0e1), isNull);
    });
  });
}
