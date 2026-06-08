/// A profile's "Déjà vu" mark on a single movie.
///
/// Identity is `(profileId, movieId)` ; `markedAt` is state, not
/// identity. Mirrors the polymorphic `(profile_id, media_kind,
/// media_id)` schema documented in `SEEN_FEATURE.md`, restricted to
/// movies at MVP — series are deferred, matching the "Jamais vus" row
/// which is also film-only (cf. add-series-viewing/design.md D-5).
///
/// Unlike [WatchProgress.completed] (which means "watched to the end
/// inside the app"), a [SeenMark] is an explicit, position-less user
/// statement: "we already saw this, elsewhere". Both feed the
/// "already seen" union the homepage uses to filter "Jamais vus".
class SeenMark {
  final String profileId;
  final String movieId;
  final DateTime markedAt;

  SeenMark({
    required this.profileId,
    required this.movieId,
    required this.markedAt,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SeenMark &&
          other.profileId == profileId &&
          other.movieId == movieId);

  @override
  int get hashCode => Object.hash(profileId, movieId);

  @override
  String toString() =>
      'SeenMark(profileId: $profileId, movieId: $movieId, '
      'markedAt: $markedAt)';
}
