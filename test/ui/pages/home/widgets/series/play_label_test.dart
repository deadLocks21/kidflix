import 'package:flutter_test/flutter_test.dart';
import 'package:kidflix/core/application/dtos/continue_watching_item.dto.dart';
import 'package:kidflix/core/domain/model/media.dart';
import 'package:kidflix/core/domain/model/profile.dart';
import 'package:kidflix/core/domain/model/watch_progress.dart';
import 'package:kidflix/ui/pages/home/widgets/series/play_label.dart';

Episode _ep({
  required String id,
  required int seasonNumber,
  required int episodeNumber,
}) =>
    Episode(
      id: id,
      seriesId: 'pingu',
      seasonNumber: seasonNumber,
      episodeNumber: episodeNumber,
      title: 'Ep $seasonNumber.$episodeNumber',
      duration: const Duration(minutes: 5),
      ageCategory: AgeCategory.enfant,
      addedAt: DateTime(2026, 5, 1),
    );

Series _series(List<Season> seasons) {
  final epCount = seasons.fold<int>(0, (s, sn) => s + sn.episodes.length);
  return Series(
    id: 'pingu',
    title: 'Pingu',
    synopsis: '',
    ageCategory: AgeCategory.enfant,
    genres: const [],
    director: const [],
    cast: const [],
    addedAt: DateTime(2026, 5, 1),
    seasonsCount: seasons.length,
    episodesCount: epCount,
    seasons: seasons,
  );
}

EpisodeProgress _progress(String episodeId, {required bool completed}) =>
    EpisodeProgress(
      profileId: 'p1',
      episodeId: episodeId,
      positionSeconds: completed ? 290 : 100,
      completed: completed,
      updatedAt: DateTime(2026, 5, 4),
    );

void main() {
  group('playLabelFor', () {
    test('no progress → "Lire S1E1"', () {
      final series = _series([
        Season(seasonNumber: 1, episodes: [
          _ep(id: 's1e1', seasonNumber: 1, episodeNumber: 1),
        ]),
      ]);
      final label = playLabelFor(series: series, latestProgress: null);
      expect(label, isNotNull);
      expect(label!.label, 'Lire S1E1');
      expect(label.target.id, 's1e1');
      expect(label.resumeSeconds, 0);
      expect(label.state, ContinueWatchingState.never);
    });

    test('in-progress → "Reprendre S{n}E{m}"', () {
      final series = _series([
        Season(seasonNumber: 1, episodes: [
          _ep(id: 's1e3', seasonNumber: 1, episodeNumber: 3),
        ]),
      ]);
      final label = playLabelFor(
        series: series,
        latestProgress: _progress('s1e3', completed: false),
      );
      expect(label!.label, 'Reprendre S1E3');
      expect(label.target.id, 's1e3');
      expect(label.resumeSeconds, 100);
      expect(label.state, ContinueWatchingState.inProgress);
    });

    test('completed mid-season → "Lire S{n}E{m+1}"', () {
      final series = _series([
        Season(seasonNumber: 1, episodes: [
          _ep(id: 's1e3', seasonNumber: 1, episodeNumber: 3),
          _ep(id: 's1e4', seasonNumber: 1, episodeNumber: 4),
        ]),
      ]);
      final label = playLabelFor(
        series: series,
        latestProgress: _progress('s1e3', completed: true),
      );
      expect(label!.label, 'Lire S1E4');
      expect(label.target.id, 's1e4');
      expect(label.state, ContinueWatchingState.nextAfterCompleted);
    });

    test('completed last → "Revoir S1E1"', () {
      final series = _series([
        Season(seasonNumber: 1, episodes: [
          _ep(id: 's1e1', seasonNumber: 1, episodeNumber: 1),
          _ep(id: 's1e2', seasonNumber: 1, episodeNumber: 2),
        ]),
      ]);
      final label = playLabelFor(
        series: series,
        latestProgress: _progress('s1e2', completed: true),
      );
      expect(label!.label, 'Revoir S1E1');
      expect(label.target.id, 's1e1');
      expect(label.state, ContinueWatchingState.restart);
    });

    test('series with only Specials → null', () {
      final series = _series([
        Season(seasonNumber: 0, name: 'Specials', episodes: [
          _ep(id: 'sp1', seasonNumber: 0, episodeNumber: 1),
        ]),
      ]);
      final label = playLabelFor(series: series, latestProgress: null);
      expect(label, isNull);
    });
  });
}
