import 'package:flutter_test/flutter_test.dart';
import 'package:kidflix/core/application/usecases/save_watch_progress.usecase.dart';
import 'package:kidflix/core/domain/model/media.dart';
import 'package:kidflix/core/domain/model/profile.dart';
import 'package:kidflix/core/domain/model/watch_progress.dart';
import 'package:kidflix/core/domain/services/watch_progress.repository.dart';

void main() {
  test('saves a MovieProgress built from movieId params', () async {
    final fake = _FakeRepo();
    final useCase = SaveWatchProgressUseCase(fake);
    final before = DateTime.now();
    await useCase.execute(
      profileId: 'p1',
      movieId: 'abc',
      positionSeconds: 300,
      completed: false,
    );
    final after = DateTime.now();

    expect(fake.saved, hasLength(1));
    final saved = fake.saved.first as MovieProgress;
    expect(saved.profileId, 'p1');
    expect(saved.movieId, 'abc');
    expect(saved.positionSeconds, 300);
    expect(saved.completed, isFalse);
    expect(
      saved.updatedAt.isAfter(before.subtract(const Duration(seconds: 1))),
      isTrue,
    );
    expect(
      saved.updatedAt.isBefore(after.add(const Duration(seconds: 1))),
      isTrue,
    );
  });

  group('executeForMedia (polymorphic)', () {
    test('builds a MovieProgress when given a Movie', () async {
      final fake = _FakeRepo();
      final useCase = SaveWatchProgressUseCase(fake);
      final movie = Movie(
        id: 'nemo',
        title: 'Nemo',
        duration: const Duration(minutes: 100),
        synopsis: '',
        ageCategory: AgeCategory.enfant,
        genres: const [],
        director: const [],
        cast: const [],
        addedAt: DateTime(2026, 1, 1),
      );

      await useCase.executeForMedia(
        profileId: 'p1',
        media: movie,
        positionSeconds: 100,
        completed: false,
      );

      expect(fake.saved, hasLength(1));
      expect(fake.saved.single, isA<MovieProgress>());
      expect((fake.saved.single as MovieProgress).movieId, 'nemo');
    });

    test('builds an EpisodeProgress when given an Episode', () async {
      final fake = _FakeRepo();
      final useCase = SaveWatchProgressUseCase(fake);
      final episode = Episode(
        id: 'ep-1',
        seriesId: 'pingu',
        seasonNumber: 1,
        episodeNumber: 1,
        title: 'Hello',
        duration: const Duration(minutes: 5),
        ageCategory: AgeCategory.enfant,
        addedAt: DateTime(2026, 1, 1),
      );

      await useCase.executeForMedia(
        profileId: 'p1',
        media: episode,
        positionSeconds: 240,
        completed: false,
      );

      expect(fake.saved, hasLength(1));
      expect(fake.saved.single, isA<EpisodeProgress>());
      expect((fake.saved.single as EpisodeProgress).episodeId, 'ep-1');
    });
  });
}

class _FakeRepo implements WatchProgressRepository {
  final saved = <WatchProgress>[];

  @override
  Future<void> save(WatchProgress progress) async {
    saved.add(progress);
  }

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
  Future<List<WatchProgress>> listForProfile(String profileId) async => [];
}
