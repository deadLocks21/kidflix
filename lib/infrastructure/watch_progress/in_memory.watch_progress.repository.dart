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
///
/// [save] always stores the new entry with `dismissed = false` to
/// mirror the server-side auto-reset rule documented in
/// `DISMISS_FEATURE.md`. [dismissMovie] / [dismissEpisode] (and their
/// `unDismiss` counterparts) are no-ops on unknown pairs — the in-memory
/// repo doesn't surface the HTTP `404` since callers always dismiss an
/// entry that the rail just displayed.
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
        _movies[_key(profileId, movieId)] = MovieProgress(
          profileId: profileId,
          movieId: movieId,
          positionSeconds: progress.positionSeconds,
          completed: progress.completed,
          updatedAt: progress.updatedAt,
        );
      case EpisodeProgress(:final profileId, :final episodeId):
        _episodes[_key(profileId, episodeId)] = EpisodeProgress(
          profileId: profileId,
          episodeId: episodeId,
          positionSeconds: progress.positionSeconds,
          completed: progress.completed,
          updatedAt: progress.updatedAt,
        );
    }
  }

  @override
  Future<List<WatchProgress>> listForProfile(String profileId) async {
    final movies = _movies.values.where((p) => p.profileId == profileId);
    final episodes = _episodes.values.where((p) => p.profileId == profileId);
    return <WatchProgress>[...movies, ...episodes];
  }

  @override
  Future<void> dismissMovie({
    required String profileId,
    required String movieId,
  }) async => _setMovieDismissed(profileId, movieId, true);

  @override
  Future<void> unDismissMovie({
    required String profileId,
    required String movieId,
  }) async => _setMovieDismissed(profileId, movieId, false);

  @override
  Future<void> dismissEpisode({
    required String profileId,
    required String episodeId,
  }) async => _setEpisodeDismissed(profileId, episodeId, true);

  @override
  Future<void> unDismissEpisode({
    required String profileId,
    required String episodeId,
  }) async => _setEpisodeDismissed(profileId, episodeId, false);

  void _setMovieDismissed(String profileId, String movieId, bool value) {
    final existing = _movies[_key(profileId, movieId)];
    if (existing == null) return;
    _movies[_key(profileId, movieId)] = MovieProgress(
      profileId: existing.profileId,
      movieId: existing.movieId,
      positionSeconds: existing.positionSeconds,
      completed: existing.completed,
      dismissed: value,
      updatedAt: existing.updatedAt,
    );
  }

  void _setEpisodeDismissed(String profileId, String episodeId, bool value) {
    final existing = _episodes[_key(profileId, episodeId)];
    if (existing == null) return;
    _episodes[_key(profileId, episodeId)] = EpisodeProgress(
      profileId: existing.profileId,
      episodeId: existing.episodeId,
      positionSeconds: existing.positionSeconds,
      completed: existing.completed,
      dismissed: value,
      updatedAt: existing.updatedAt,
    );
  }
}
