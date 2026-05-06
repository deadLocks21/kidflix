import 'package:kidflix/core/domain/model/watch_progress.dart';
import 'package:kidflix/core/domain/services/watch_progress.repository.dart';

/// RAM-only [WatchProgressRepository] used until the backend lands.
///
/// Entries are lost at app restart — acceptable for MVP. The HTTP
/// replacement will preserve the same contract.
///
/// Internally uses two maps keyed on `(profileId, mediaId)` — one per
/// kind — so that a `MovieProgress(profileId: 'p', movieId: 'x')` and
/// an `EpisodeProgress(profileId: 'p', episodeId: 'x')` (same string
/// id) coexist independently, matching the server-side schema where the
/// composite key is `(profile_id, media_kind, media_id)`.
class InMemoryWatchProgressRepository implements WatchProgressRepository {
  final Map<String, MovieProgress> _movies = {};
  final Map<String, EpisodeProgress> _episodes = {};

  String _key(String profileId, String mediaId) => '$profileId|$mediaId';

  @override
  Future<MovieProgress?> findForMovie({
    required String profileId,
    required String movieId,
  }) async {
    return _movies[_key(profileId, movieId)];
  }

  @override
  Future<EpisodeProgress?> findForEpisode({
    required String profileId,
    required String episodeId,
  }) async {
    return _episodes[_key(profileId, episodeId)];
  }

  @override
  Future<void> save(WatchProgress progress) async {
    switch (progress) {
      case MovieProgress(:final profileId, :final movieId):
        _movies[_key(profileId, movieId)] = progress;
      case EpisodeProgress(:final profileId, :final episodeId):
        _episodes[_key(profileId, episodeId)] = progress;
    }
  }

  @override
  Future<List<WatchProgress>> listForProfile(String profileId) async {
    final movies = _movies.values.where((p) => p.profileId == profileId);
    final episodes = _episodes.values.where((p) => p.profileId == profileId);
    return <WatchProgress>[...movies, ...episodes];
  }
}
