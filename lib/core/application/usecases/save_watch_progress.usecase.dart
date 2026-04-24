import 'package:kidflix/core/domain/model/watch_progress.dart';
import 'package:kidflix/core/domain/services/watch_progress.repository.dart';

/// Upserts a playback progress entry for `(profileId, movieId)`.
///
/// The usecase constructs the [WatchProgress] domain instance with
/// `updatedAt = DateTime.now()` — the UI doesn't need to manage
/// timestamps.
class SaveWatchProgressUseCase {
  final WatchProgressRepository _repository;

  const SaveWatchProgressUseCase(this._repository);

  Future<void> execute({
    required String profileId,
    required String movieId,
    required int positionSeconds,
    required bool completed,
  }) {
    final progress = WatchProgress(
      profileId: profileId,
      movieId: movieId,
      positionSeconds: positionSeconds,
      completed: completed,
      updatedAt: DateTime.now(),
    );
    return _repository.save(progress);
  }
}
