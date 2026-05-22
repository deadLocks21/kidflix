import 'package:flutter_test/flutter_test.dart';
import 'package:kidflix/core/application/dtos/continue_watching_card.dto.dart';
import 'package:kidflix/core/application/usecases/dismiss_continue_watching.usecase.dart';
import 'package:kidflix/core/domain/model/watch_progress.dart';
import 'package:kidflix/core/domain/services/watch_progress.repository.dart';

class _RecordingRepo implements WatchProgressRepository {
  _RecordingRepo({List<WatchProgress> seed = const []}) : _entries = [...seed];

  final List<WatchProgress> _entries;
  final List<String> dismissedMovies = [];
  final List<String> dismissedEpisodes = [];

  @override
  Future<MovieProgress?> findForMovie({
    required String profileId,
    required String movieId,
  }) async => null;
  @override
  Future<EpisodeProgress?> findForEpisode({
    required String profileId,
    required String episodeId,
  }) async => null;
  @override
  Future<void> save(WatchProgress progress) async {}
  @override
  Future<List<WatchProgress>> listForProfile(String profileId) async =>
      _entries.where((e) => e.profileId == profileId).toList();
  @override
  Future<void> dismissMovie({
    required String profileId,
    required String movieId,
  }) async {
    dismissedMovies.add(movieId);
  }

  @override
  Future<void> unDismissMovie({
    required String profileId,
    required String movieId,
  }) async {}
  @override
  Future<void> dismissEpisode({
    required String profileId,
    required String episodeId,
  }) async {
    dismissedEpisodes.add(episodeId);
  }

  @override
  Future<void> unDismissEpisode({
    required String profileId,
    required String episodeId,
  }) async {}
}

EpisodeProgress _ep(
  String id, {
  bool dismissed = false,
  bool completed = false,
}) => EpisodeProgress(
  profileId: 'p1',
  episodeId: id,
  positionSeconds: 100,
  completed: completed,
  dismissed: dismissed,
  updatedAt: DateTime.utc(2026, 5, 1),
);

void main() {
  group('DismissContinueWatchingUseCase', () {
    test('movie target → single dismissMovie call', () async {
      final repo = _RecordingRepo();
      final uc = DismissContinueWatchingUseCase(repo);

      await uc.execute(
        profileId: 'p1',
        target: const MovieDismissTarget('nemo'),
      );

      expect(repo.dismissedMovies, ['nemo']);
      expect(repo.dismissedEpisodes, isEmpty);
    });

    test('series target sweeps all episode progresses of the series', () async {
      // User has progresses on s1e1 (completed), s1e2 (in-progress), and
      // s2e1 (in-progress) of the same series. The CW row only shows
      // one card (dedup) ; dismissing the card must remove ALL three so
      // an older entry doesn't resurface immediately.
      final repo = _RecordingRepo(
        seed: [_ep('s1e1', completed: true), _ep('s1e2'), _ep('s2e1')],
      );
      final uc = DismissContinueWatchingUseCase(repo);

      await uc.execute(
        profileId: 'p1',
        target: const SeriesDismissTarget(
          seriesId: 'pingu',
          episodeIds: ['s1e1', 's1e2', 's2e1', 's3e1' /* no progress */],
        ),
      );

      expect(repo.dismissedEpisodes.toSet(), {'s1e1', 's1e2', 's2e1'});
      expect(repo.dismissedMovies, isEmpty);
    });

    test('series target skips already-dismissed episodes', () async {
      final repo = _RecordingRepo(
        seed: [_ep('s1e1', dismissed: true), _ep('s1e2')],
      );
      final uc = DismissContinueWatchingUseCase(repo);

      await uc.execute(
        profileId: 'p1',
        target: const SeriesDismissTarget(
          seriesId: 'pingu',
          episodeIds: ['s1e1', 's1e2'],
        ),
      );

      expect(repo.dismissedEpisodes, ['s1e2']);
    });

    test(
      'series target ignores episodes outside the series universe',
      () async {
        // Same profile has progress on an episode from another series.
        // It must NOT be swept.
        final repo = _RecordingRepo(
          seed: [_ep('pingu-s1e1'), _ep('barbapapa-s1e1')],
        );
        final uc = DismissContinueWatchingUseCase(repo);

        await uc.execute(
          profileId: 'p1',
          target: const SeriesDismissTarget(
            seriesId: 'pingu',
            episodeIds: ['pingu-s1e1'],
          ),
        );

        expect(repo.dismissedEpisodes, ['pingu-s1e1']);
      },
    );

    test('series target with no matching progress is a silent no-op', () async {
      final repo = _RecordingRepo(seed: const []);
      final uc = DismissContinueWatchingUseCase(repo);

      await uc.execute(
        profileId: 'p1',
        target: const SeriesDismissTarget(
          seriesId: 'pingu',
          episodeIds: ['s1e1'],
        ),
      );

      expect(repo.dismissedEpisodes, isEmpty);
    });
  });
}
