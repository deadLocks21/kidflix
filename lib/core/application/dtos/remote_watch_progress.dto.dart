import 'package:kidflix/core/domain/model/watch_progress.dart';

/// Parses a single wire entry of the `/progress/movies/{m}`,
/// `/progress/episodes/{e}` (single object) or `/profiles/{p}/progress`
/// (mixed list) responses into a Domain [WatchProgress] sealed.
///
/// The wire shape is:
///
/// ```json
/// {
///   "kind": "movie" | "episode",
///   "profile_id": "...",
///   "media_id": "...",         // movie_id ou episode_id selon kind
///   "position_seconds": 1845,
///   "completed": false,
///   "dismissed": false,
///   "updated_at": "2026-04-22T10:30:00Z"
/// }
/// ```
///
/// `dismissed` is documented as always present once the backend rollout
/// of `add-progress-dismiss` lands, but we default to `false` when the
/// key is missing so the client keeps working against an older backend
/// during the deployment window.
///
/// Fail-fast on missing or unknown `kind` (FormatException).
WatchProgress watchProgressFromJson(Map<String, dynamic> json) {
  final kind = json['kind'];
  final profileId = json['profile_id'] as String;
  final mediaId = json['media_id'] as String;
  final positionSeconds = json['position_seconds'] as int;
  final completed = json['completed'] as bool;
  final dismissed = (json['dismissed'] as bool?) ?? false;
  final updatedAt = DateTime.parse(json['updated_at'] as String);

  switch (kind) {
    case 'movie':
      return MovieProgress(
        profileId: profileId,
        movieId: mediaId,
        positionSeconds: positionSeconds,
        completed: completed,
        dismissed: dismissed,
        updatedAt: updatedAt,
      );
    case 'episode':
      return EpisodeProgress(
        profileId: profileId,
        episodeId: mediaId,
        positionSeconds: positionSeconds,
        completed: completed,
        dismissed: dismissed,
        updatedAt: updatedAt,
      );
    default:
      throw FormatException('Unknown progress kind: $kind');
  }
}

/// Builds the body of a `PUT /profiles/{p}/progress/{movies|episodes}/{id}`
/// request.
///
/// The PUT body intentionally omits `profile_id`, `media_id` (both
/// travel in the URL path), `kind` (carried by the path), `dismissed`
/// (server-managed — auto-reset to false on every save) and
/// `updated_at` (the server stamps its own clock — any client-supplied
/// value would be ignored).
Map<String, dynamic> watchProgressToWireBody(WatchProgress progress) => {
      'position_seconds': progress.positionSeconds,
      'completed': progress.completed,
    };
