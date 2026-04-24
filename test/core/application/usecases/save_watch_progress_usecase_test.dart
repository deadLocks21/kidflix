import 'package:flutter_test/flutter_test.dart';
import 'package:kidflix/core/application/usecases/save_watch_progress.usecase.dart';
import 'package:kidflix/core/domain/model/watch_progress.dart';
import 'package:kidflix/core/domain/services/watch_progress.repository.dart';

void main() {
  test('saves a domain WatchProgress built from params', () async {
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
    final saved = fake.saved.first;
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
}

class _FakeRepo implements WatchProgressRepository {
  final saved = <WatchProgress>[];

  @override
  Future<void> save(WatchProgress progress) async {
    saved.add(progress);
  }

  @override
  Future<WatchProgress?> findFor({
    required String profileId,
    required String movieId,
  }) async => null;

  @override
  Future<List<WatchProgress>> listForProfile(String profileId) async => [];
}
