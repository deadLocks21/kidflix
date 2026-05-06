import 'package:flutter_test/flutter_test.dart';
import 'package:kidflix/core/application/usecases/get_watch_progress.usecase.dart';
import 'package:kidflix/core/domain/model/watch_progress.dart';
import 'package:kidflix/core/domain/services/watch_progress.repository.dart';

void main() {
  test('returns null when repo returns null', () async {
    final useCase = GetWatchProgressUseCase(_FakeRepo(value: null));
    final result = await useCase.execute(profileId: 'p1', movieId: 'abc');
    expect(result, isNull);
  });

  test('maps domain to DTO when repo returns progress', () async {
    final domain = MovieProgress(
      profileId: 'p1',
      movieId: 'abc',
      positionSeconds: 1800,
      completed: false,
      updatedAt: DateTime(2026, 4, 24),
    );
    final useCase = GetWatchProgressUseCase(_FakeRepo(value: domain));
    final result = await useCase.execute(profileId: 'p1', movieId: 'abc');
    expect(result, isNotNull);
    expect(result!.profileId, 'p1');
    expect(result.movieId, 'abc');
    expect(result.positionSeconds, 1800);
    expect(result.completed, isFalse);
  });
}

class _FakeRepo implements WatchProgressRepository {
  _FakeRepo({this.value});

  final MovieProgress? value;

  @override
  Future<MovieProgress?> findForMovie({
    required String profileId,
    required String movieId,
  }) async => value;

  @override
  Future<EpisodeProgress?> findForEpisode({
    required String profileId,
    required String episodeId,
  }) async => null;

  @override
  Future<void> save(WatchProgress progress) async {}

  @override
  Future<List<WatchProgress>> listForProfile(String profileId) async => [];
}
