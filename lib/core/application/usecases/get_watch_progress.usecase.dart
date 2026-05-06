import 'package:kidflix/core/application/dtos/watch_progress.dto.dart';
import 'package:kidflix/core/domain/services/watch_progress.repository.dart';

/// Returns the stored playback progress for `(profileId, movieId)`, or
/// `null` when none exists.
class GetWatchProgressUseCase {
  final WatchProgressRepository _repository;

  const GetWatchProgressUseCase(this._repository);

  Future<WatchProgressDto?> execute({
    required String profileId,
    required String movieId,
  }) async {
    final domain = await _repository.findForMovie(
      profileId: profileId,
      movieId: movieId,
    );
    return domain == null ? null : WatchProgressDto.fromDomain(domain);
  }
}
