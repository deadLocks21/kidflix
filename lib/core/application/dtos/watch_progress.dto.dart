import 'package:kidflix/core/domain/model/watch_progress.dart';

/// UI-facing projection of [WatchProgress].
class WatchProgressDto {
  final String profileId;
  final String movieId;
  final int positionSeconds;
  final bool completed;
  final DateTime updatedAt;

  const WatchProgressDto({
    required this.profileId,
    required this.movieId,
    required this.positionSeconds,
    required this.completed,
    required this.updatedAt,
  });

  factory WatchProgressDto.fromDomain(WatchProgress progress) =>
      WatchProgressDto(
        profileId: progress.profileId,
        movieId: progress.movieId,
        positionSeconds: progress.positionSeconds,
        completed: progress.completed,
        updatedAt: progress.updatedAt,
      );

  WatchProgress toDomain() => WatchProgress(
    profileId: profileId,
    movieId: movieId,
    positionSeconds: positionSeconds,
    completed: completed,
    updatedAt: updatedAt,
  );
}
