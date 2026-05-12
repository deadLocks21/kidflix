/// Playback progress of a single playable media item for a single profile.
///
/// Two progresses share identity by `(profileId, mediaId)` within their
/// own kind — position and timestamp are state, not identity. The
/// repository uses this identity for upsert semantics: saving a new
/// progress for an existing pair replaces the old entry.
///
/// `WatchProgress` is sealed: it is either a [MovieProgress] (keyed on
/// `movieId`) or an [EpisodeProgress] (keyed on `episodeId`). The sealed
/// modifier lets the player layer switch exhaustively without a default
/// branch.
///
/// The [dismissed] flag tracks an explicit user opt-out of the Continue
/// Watching row without modifying the position. It is server-managed:
/// the backend resets it to `false` on every successful save (cf.
/// `DISMISS_FEATURE.md` — auto-reset rule).
///
/// No `deviceId` field: device identity is a server-side concern. The
/// backend infers it from the JWT.
sealed class WatchProgress {
  String get profileId;
  int get positionSeconds;
  bool get completed;
  bool get dismissed;
  DateTime get updatedAt;
}

/// Playback progress of a movie.
///
/// Equatable by `(profileId, movieId)`. A [MovieProgress] is never equal
/// to an [EpisodeProgress] even when their string ids happen to coincide.
class MovieProgress extends WatchProgress {
  @override
  final String profileId;
  final String movieId;
  @override
  final int positionSeconds;
  @override
  final bool completed;
  @override
  final bool dismissed;
  @override
  final DateTime updatedAt;

  MovieProgress({
    required this.profileId,
    required this.movieId,
    required this.positionSeconds,
    required this.completed,
    required this.updatedAt,
    this.dismissed = false,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MovieProgress &&
          other.profileId == profileId &&
          other.movieId == movieId);

  @override
  int get hashCode => Object.hash(profileId, movieId);

  @override
  String toString() =>
      'MovieProgress(profileId: $profileId, movieId: $movieId, '
      'positionSeconds: $positionSeconds, completed: $completed, '
      'dismissed: $dismissed)';
}

/// Playback progress of an episode of a series.
///
/// Equatable by `(profileId, episodeId)`. A [EpisodeProgress] is never
/// equal to a [MovieProgress].
class EpisodeProgress extends WatchProgress {
  @override
  final String profileId;
  final String episodeId;
  @override
  final int positionSeconds;
  @override
  final bool completed;
  @override
  final bool dismissed;
  @override
  final DateTime updatedAt;

  EpisodeProgress({
    required this.profileId,
    required this.episodeId,
    required this.positionSeconds,
    required this.completed,
    required this.updatedAt,
    this.dismissed = false,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EpisodeProgress &&
          other.profileId == profileId &&
          other.episodeId == episodeId);

  @override
  int get hashCode => Object.hash(profileId, episodeId);

  @override
  String toString() =>
      'EpisodeProgress(profileId: $profileId, episodeId: $episodeId, '
      'positionSeconds: $positionSeconds, completed: $completed, '
      'dismissed: $dismissed)';
}
