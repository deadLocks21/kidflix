import 'package:flutter_test/flutter_test.dart';
import 'package:kidflix/core/domain/model/watch_progress.dart';
import 'package:kidflix/infrastructure/watch_progress/in_memory.watch_progress.repository.dart';

void main() {
  late InMemoryWatchProgressRepository repo;

  setUp(() {
    repo = InMemoryWatchProgressRepository();
  });

  test('save then findFor returns the saved entry', () async {
    final progress = WatchProgress(
      profileId: 'p1',
      movieId: 'abc',
      positionSeconds: 300,
      completed: false,
      updatedAt: DateTime(2026, 4, 24),
    );
    await repo.save(progress);
    final found = await repo.findFor(profileId: 'p1', movieId: 'abc');
    expect(found, isNotNull);
    expect(found!.positionSeconds, 300);
    expect(found.completed, isFalse);
  });

  test('second save overwrites the first', () async {
    await repo.save(
      WatchProgress(
        profileId: 'p1',
        movieId: 'abc',
        positionSeconds: 300,
        completed: false,
        updatedAt: DateTime(2026, 4, 24, 10),
      ),
    );
    await repo.save(
      WatchProgress(
        profileId: 'p1',
        movieId: 'abc',
        positionSeconds: 600,
        completed: true,
        updatedAt: DateTime(2026, 4, 24, 11),
      ),
    );
    final found = await repo.findFor(profileId: 'p1', movieId: 'abc');
    expect(found!.positionSeconds, 600);
    expect(found.completed, isTrue);
  });

  test('findFor on unknown pair returns null', () async {
    final found = await repo.findFor(profileId: 'p1', movieId: 'unknown');
    expect(found, isNull);
  });

  test('listForProfile filters by profileId', () async {
    await repo.save(
      WatchProgress(
        profileId: 'p1',
        movieId: 'abc',
        positionSeconds: 100,
        completed: false,
        updatedAt: DateTime(2026, 4, 24),
      ),
    );
    await repo.save(
      WatchProgress(
        profileId: 'p1',
        movieId: 'def',
        positionSeconds: 200,
        completed: false,
        updatedAt: DateTime(2026, 4, 24),
      ),
    );
    await repo.save(
      WatchProgress(
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
      p1Entries.map((e) => e.movieId).toSet(),
      equals({'abc', 'def'}),
    );
  });

  test('listForProfile returns empty when profile has no entries', () async {
    expect(await repo.listForProfile('unknown'), isEmpty);
  });
}
