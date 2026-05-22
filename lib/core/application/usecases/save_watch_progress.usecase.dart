import 'package:kidflix/core/domain/model/media.dart';
import 'package:kidflix/core/domain/model/watch_progress.dart';
import 'package:kidflix/core/domain/services/watch_progress.repository.dart';

/// Upserts a playback progress entry for a profile.
///
/// Two convenience entry points:
///
/// * [execute] takes a `movieId` String — preserved for backwards
///   compatibility with the movie-only `PlayerPage`.
/// * [executeForMedia] takes a sealed [PlayableMedia] and is the
///   forward-looking signature used by the episode pipeline.
///
/// Both build the right [WatchProgress] subtype and forward to
/// [WatchProgressRepository.save] which dispatches by sealed.
///
/// `updatedAt = DateTime.now()` — the UI doesn't manage timestamps.
/// The server stamps its own clock and ignores this field
/// (cf. `API.md` § Progression de lecture).
class SaveWatchProgressUseCase {
  final WatchProgressRepository _repository;

  const SaveWatchProgressUseCase(this._repository);

  Future<void> execute({
    required String profileId,
    required String movieId,
    required int positionSeconds,
    required bool completed,
  }) {
    final progress = MovieProgress(
      profileId: profileId,
      movieId: movieId,
      positionSeconds: positionSeconds,
      completed: completed,
      updatedAt: DateTime.now(),
    );
    return _repository.save(progress);
  }

  Future<void> executeForMedia({
    required String profileId,
    required PlayableMedia media,
    required int positionSeconds,
    required bool completed,
  }) {
    final WatchProgress progress = switch (media) {
      Movie() => MovieProgress(
        profileId: profileId,
        movieId: media.id,
        positionSeconds: positionSeconds,
        completed: completed,
        updatedAt: DateTime.now(),
      ),
      Episode() => EpisodeProgress(
        profileId: profileId,
        episodeId: media.id,
        positionSeconds: positionSeconds,
        completed: completed,
        updatedAt: DateTime.now(),
      ),
    };
    return _repository.save(progress);
  }
}
