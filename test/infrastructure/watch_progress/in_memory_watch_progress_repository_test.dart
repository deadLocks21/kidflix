import 'package:flutter_test/flutter_test.dart';
import 'package:kidflix/core/domain/model/watch_progress.dart';
import 'package:kidflix/infrastructure/watch_progress/in_memory.watch_progress.repository.dart';

void main() {
  late InMemoryWatchProgressRepository repo;

  setUp(() {
    repo = InMemoryWatchProgressRepository();
  });

  test('save then findFor returns the saved entry', () async {
    final progress = MovieProgress(
      profileId: 'p1',
      movieId: 'abc',
      positionSeconds: 300,
      completed: false,
      updatedAt: DateTime(2026, 4, 24),
    );
    await repo.save(progress);
    final found = await repo.findForMovie(profileId: 'p1', movieId: 'abc');
    expect(found, isNotNull);
    expect(found!.positionSeconds, 300);
    expect(found.completed, isFalse);
  });

  test('second save overwrites the first', () async {
    await repo.save(
      MovieProgress(
        profileId: 'p1',
        movieId: 'abc',
        positionSeconds: 300,
        completed: false,
        updatedAt: DateTime(2026, 4, 24, 10),
      ),
    );
    await repo.save(
      MovieProgress(
        profileId: 'p1',
        movieId: 'abc',
        positionSeconds: 600,
        completed: true,
        updatedAt: DateTime(2026, 4, 24, 11),
      ),
    );
    final found = await repo.findForMovie(profileId: 'p1', movieId: 'abc');
    expect(found!.positionSeconds, 600);
    expect(found.completed, isTrue);
  });

  test('findFor on unknown pair returns null', () async {
    final found = await repo.findForMovie(profileId: 'p1', movieId: 'unknown');
    expect(found, isNull);
  });

  test('listForProfile filters by profileId', () async {
    await repo.save(
      MovieProgress(
        profileId: 'p1',
        movieId: 'abc',
        positionSeconds: 100,
        completed: false,
        updatedAt: DateTime(2026, 4, 24),
      ),
    );
    await repo.save(
      MovieProgress(
        profileId: 'p1',
        movieId: 'def',
        positionSeconds: 200,
        completed: false,
        updatedAt: DateTime(2026, 4, 24),
      ),
    );
    await repo.save(
      MovieProgress(
        profileId: 'p2',
        movieId: 'abc',
        positionSeconds: 50,
        completed: false,
        updatedAt: DateTime(2026, 4, 24),
      ),
    );
    final p1Entries = await repo.listForProfile('p1');
    expect(p1Entries, hasLength(2));
    expect(
      p1Entries.map((e) => (e as MovieProgress).movieId).toSet(),
      equals({'abc', 'def'}),
    );
  });

  test('listForProfile returns empty when profile has no entries', () async {
    expect(await repo.listForProfile('unknown'), isEmpty);
  });

  group('episode pipeline', () {
    test('saves and retrieves an EpisodeProgress', () async {
      final repo = InMemoryWatchProgressRepository();
      await repo.save(
        EpisodeProgress(
          profileId: 'p1',
          episodeId: 'ep-1',
          positionSeconds: 240,
          completed: false,
          updatedAt: DateTime.utc(2026, 5, 4),
        ),
      );

      final found =
          await repo.findForEpisode(profileId: 'p1', episodeId: 'ep-1');
      expect(found, isNotNull);
      expect(found!.episodeId, 'ep-1');
      expect(found.positionSeconds, 240);
    });

    test('movie and episode with same string id are stored independently',
        () async {
      final repo = InMemoryWatchProgressRepository();
      await repo.save(
        MovieProgress(
          profileId: 'p1',
          movieId: 'x',
          positionSeconds: 100,
          completed: false,
          updatedAt: DateTime.utc(2026, 5, 1),
        ),
      );
      await repo.save(
        EpisodeProgress(
          profileId: 'p1',
          episodeId: 'x',
          positionSeconds: 50,
          completed: true,
          updatedAt: DateTime.utc(2026, 5, 4),
        ),
      );

      final movie = await repo.findForMovie(profileId: 'p1', movieId: 'x');
      final episode =
          await repo.findForEpisode(profileId: 'p1', episodeId: 'x');
      expect(movie!.positionSeconds, 100);
      expect(movie.completed, isFalse);
      expect(episode!.positionSeconds, 50);
      expect(episode.completed, isTrue);
    });

    test('listForProfile returns mixed kinds', () async {
      final repo = InMemoryWatchProgressRepository();
      await repo.save(
        MovieProgress(
          profileId: 'p1',
          movieId: 'm1',
          positionSeconds: 100,
          completed: false,
          updatedAt: DateTime.utc(2026, 5, 1),
        ),
      );
      await repo.save(
        EpisodeProgress(
          profileId: 'p1',
          episodeId: 'e1',
          positionSeconds: 50,
          completed: false,
          updatedAt: DateTime.utc(2026, 5, 4),
        ),
      );

      final entries = await repo.listForProfile('p1');
      expect(entries, hasLength(2));
      expect(entries.whereType<MovieProgress>(), hasLength(1));
      expect(entries.whereType<EpisodeProgress>(), hasLength(1));
    });
  });
}
