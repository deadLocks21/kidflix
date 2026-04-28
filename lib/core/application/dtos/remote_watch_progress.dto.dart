import 'package:kidflix/core/domain/model/watch_progress.dart';

/// Wire-format DTO mediating between the JSON payload of the three
/// watch-progress endpoints (cf. `API.md` § Progression de lecture) and
/// the Domain [WatchProgress] entity.
///
/// [fromJson] / [toDomain] are used for the GET responses, [toWireBody]
/// for the `PUT /profiles/{pid}/progress/{mid}` request body. The PUT
/// body intentionally omits `profile_id` / `movie_id` (both travel in
/// the URL path) and `updated_at` (the server stamps its own clock —
/// any client-supplied value would be ignored).
class RemoteWatchProgressDto {
  final String profileId;
  final String movieId;
  final int positionSeconds;
  final bool completed;
  final DateTime updatedAt;

  const RemoteWatchProgressDto({
    required this.profileId,
    required this.movieId,
    required this.positionSeconds,
    required this.completed,
    required this.updatedAt,
  });

  factory RemoteWatchProgressDto.fromJson(Map<String, dynamic> json) =>
      RemoteWatchProgressDto(
        profileId: json['profile_id'] as String,
        movieId: json['movie_id'] as String,
        positionSeconds: json['position_seconds'] as int,
        completed: json['completed'] as bool,
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );

  WatchProgress toDomain() => WatchProgress(
    profileId: profileId,
    movieId: movieId,
    positionSeconds: positionSeconds,
    completed: completed,
    updatedAt: updatedAt,
  );

  Map<String, dynamic> toWireBody() => {
    'position_seconds': positionSeconds,
    'completed': completed,
  };
}
