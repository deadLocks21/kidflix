import 'package:kidflix/core/application/dtos/movie.dto.dart';
import 'package:kidflix/core/domain/model/media.dart';

/// Why a Continue Watching entry was emitted for a series.
///
/// * [never] — the user has never started this series. Not emitted by
///   `ResolveContinueWatchingUseCase` itself (it only sees profiles
///   with at least one progress) but used by the helper
///   `resolveContinueWatchingForSeries` consumed by the series detail
///   modal to compute the smart "Lire" button label.
/// * [inProgress] — the most recent episode of the series is in
///   progress (not completed). Resume at `progress.positionSeconds`.
/// * [nextAfterCompleted] — the most recent episode is completed and
///   another episode exists in the rotation (next in the same season,
///   or first of the next season). Start that next episode at 0.
/// * [restart] — the most recent episode is completed and there is no
///   next episode (end of series, ignoring Specials). Restart at S1E1.
enum ContinueWatchingState {
  never,
  inProgress,
  nextAfterCompleted,
  restart,
}

/// Sealed projection of one entry in the Continue Watching row.
sealed class ContinueWatchingItemDto {
  String get id;
  int get resumeSeconds;
}

/// A movie entry — render as a standard movie card with a resume bar.
class MovieContinueDto extends ContinueWatchingItemDto {
  final MovieDto movie;
  @override
  final int resumeSeconds;
  final bool completed;

  MovieContinueDto({
    required this.movie,
    required this.resumeSeconds,
    required this.completed,
  });

  @override
  String get id => movie.id;
}

/// An episode entry — render as a series-specific card showing the
/// series title, the episode reference (`S{n}E{m}`), and (when
/// applicable) a resume bar.
class EpisodeContinueDto extends ContinueWatchingItemDto {
  final Series series;
  final Episode episode;
  @override
  final int resumeSeconds;
  final ContinueWatchingState kind;

  EpisodeContinueDto({
    required this.series,
    required this.episode,
    required this.resumeSeconds,
    required this.kind,
  });

  @override
  String get id => series.id;
}
