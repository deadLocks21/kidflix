/// Playback progress of a single movie for a single profile.
///
/// Two progresses are considered equal when they share the same
/// `(profileId, movieId)` — position and timestamp are state, not
/// identity. The repository uses this identity for upsert semantics:
/// saving a new [WatchProgress] for an existing pair replaces the old
/// entry.
///
/// No `deviceId` field: device identity is a server-side concern. The
/// backend infers it from the JWT. The client contract stays the same
/// when the in-memory implementation is replaced by the HTTP one.
class WatchProgress {
  final String profileId;
  final String movieId;
  final int positionSeconds;
  final bool completed;
  final DateTime updatedAt;

  const WatchProgress({
    required this.profileId,
    required this.movieId,
    required this.positionSeconds,
    required this.completed,
    required this.updatedAt,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WatchProgress &&
          other.profileId == profileId &&
          other.movieId == movieId);

  @override
  int get hashCode => Object.hash(profileId, movieId);

  @override
  String toString() =>
      'WatchProgress(profileId: $profileId, movieId: $movieId, '
      'positionSeconds: $positionSeconds, completed: $completed)';
}
