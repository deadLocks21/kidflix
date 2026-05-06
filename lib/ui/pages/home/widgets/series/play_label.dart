import 'package:kidflix/core/application/dtos/continue_watching_item.dto.dart';
import 'package:kidflix/core/application/usecases/resolve_continue_watching.usecase.dart';
import 'package:kidflix/core/domain/model/media.dart';
import 'package:kidflix/core/domain/model/watch_progress.dart';

/// Result of [playLabelFor]: what to display on the modal's primary
/// "Lire" button, and which [Episode] to launch when tapped.
class PlayLabel {
  final String label;
  final Episode target;
  final int resumeSeconds;
  final ContinueWatchingState state;

  const PlayLabel({
    required this.label,
    required this.target,
    required this.resumeSeconds,
    required this.state,
  });
}

/// Computes the dynamic "Lire" button label for a series detail modal,
/// based on the active profile's most recent [EpisodeProgress] for that
/// series.
///
/// * No progress → `"Lire S{n}E{m}"` pointing to the first non-Specials
///   episode (typically S1E1).
/// * In-progress → `"Reprendre S{n}E{m}"`, resume at
///   `progress.positionSeconds`.
/// * Most recent episode completed and a next exists → `"Lire S{n}E{m}"`
///   pointing to the next episode.
/// * Fully watched → `"Revoir S{n}E{m}"` pointing to S1E1.
///
/// Returns `null` when [series] has no rotation-eligible episodes
/// (i.e. only a Specials season). Callers should treat that as
/// "no playable target" and disable the button.
PlayLabel? playLabelFor({
  required Series series,
  required EpisodeProgress? latestProgress,
}) {
  // Locate the matching episode for the latest progress (if any).
  Episode? currentEp;
  if (latestProgress != null) {
    for (final s in series.seasons) {
      for (final e in s.episodes) {
        if (e.id == latestProgress.episodeId) {
          currentEp = e;
          break;
        }
      }
      if (currentEp != null) break;
    }
  }

  // No progress → first non-Specials episode.
  if (latestProgress == null || currentEp == null) {
    final first = _firstRotationEpisode(series);
    if (first == null) return null;
    return PlayLabel(
      label: 'Lire ${_formatRef(first)}',
      target: first,
      resumeSeconds: 0,
      state: ContinueWatchingState.never,
    );
  }

  final resolution = resolveContinueWatchingForSeries(
    series: series,
    currentEpisode: currentEp,
    currentProgress: latestProgress,
  );
  if (resolution == null) return null;

  final prefix = switch (resolution.state) {
    ContinueWatchingState.inProgress => 'Reprendre',
    ContinueWatchingState.nextAfterCompleted => 'Lire',
    ContinueWatchingState.restart => 'Revoir',
    ContinueWatchingState.never => 'Lire',
  };
  return PlayLabel(
    label: '$prefix ${_formatRef(resolution.target)}',
    target: resolution.target,
    resumeSeconds: resolution.resumeSeconds,
    state: resolution.state,
  );
}

/// First episode of the lowest non-Specials season — used for the
/// `never` and `restart` states.
Episode? _firstRotationEpisode(Series series) {
  final seasons = series.seasons.where((s) => s.seasonNumber > 0).toList()
    ..sort((a, b) => a.seasonNumber.compareTo(b.seasonNumber));
  for (final season in seasons) {
    if (season.episodes.isEmpty) continue;
    final eps = [...season.episodes]
      ..sort((a, b) => a.episodeNumber.compareTo(b.episodeNumber));
    return eps.first;
  }
  return null;
}

/// Formats an episode reference as `"S{n}E{m}"`. Specials get
/// `"S0E{m}"` for unambiguousness.
String _formatRef(Episode ep) => 'S${ep.seasonNumber}E${ep.episodeNumber}';
