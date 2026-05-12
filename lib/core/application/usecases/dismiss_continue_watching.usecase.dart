import 'package:kidflix/core/application/dtos/continue_watching_card.dto.dart';
import 'package:kidflix/core/domain/model/watch_progress.dart';
import 'package:kidflix/core/domain/services/watch_progress.repository.dart';

/// Removes a Continue Watching entry from the row without losing the
/// stored playback position.
///
/// Movie dismiss is a single repo call. Series dismiss is a sweep:
/// the row dedups by series so dismissing only the most-recent episode
/// would let the next one resurface — the use case lists the profile's
/// progresses, intersects with the series' episode ids, and dismisses
/// every non-dismissed episode in parallel. The HTTP backend resets
/// the dismissed flag automatically on the next `save`, so resuming
/// playback brings the title back without an explicit un-dismiss.
class DismissContinueWatchingUseCase {
  final WatchProgressRepository _repo;

  const DismissContinueWatchingUseCase(this._repo);

  Future<void> execute({
    required String profileId,
    required ContinueWatchingDismissTarget target,
  }) async {
    switch (target) {
      case MovieDismissTarget(:final movieId):
        await _repo.dismissMovie(profileId: profileId, movieId: movieId);
      case SeriesDismissTarget(:final episodeIds):
        final progresses = await _repo.listForProfile(profileId);
        final ids = episodeIds.toSet();
        final toDismiss = progresses
            .whereType<EpisodeProgress>()
            .where((p) => ids.contains(p.episodeId) && !p.dismissed)
            .map((p) => p.episodeId);
        await Future.wait(
          toDismiss.map(
            (id) => _repo.dismissEpisode(profileId: profileId, episodeId: id),
          ),
        );
    }
  }
}
