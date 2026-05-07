import 'package:kidflix/core/application/dtos/series_playback_context.dart';

/// Identifies the media the [PlayerPage] should play.
///
/// Sealed: a runtime-discriminated union of either a movie or an
/// episode reference. The player widget switches on this to route to
/// the right download / progress pipeline.
///
/// Carries only the id (the catalog/series repos own the metadata) —
/// title resolution happens inside the player after mount.
sealed class PlayerMediaRef {
  String get id;

  const PlayerMediaRef();

  factory PlayerMediaRef.movie(String movieId) = PlayerMovieRef;

  /// Constructs an episode reference. [seriesContext] is set when the
  /// player should expose series-aware controls (prev / next / list /
  /// shuffle auto-advance).
  factory PlayerMediaRef.episode(
    String episodeId, {
    SeriesPlaybackContext? seriesContext,
  }) = PlayerEpisodeRef;
}

class PlayerMovieRef extends PlayerMediaRef {
  final String movieId;

  const PlayerMovieRef(this.movieId);

  @override
  String get id => movieId;

  @override
  bool operator ==(Object other) =>
      other is PlayerMovieRef && other.movieId == movieId;

  @override
  int get hashCode => movieId.hashCode;
}

class PlayerEpisodeRef extends PlayerMediaRef {
  final String episodeId;
  final SeriesPlaybackContext? seriesContext;

  const PlayerEpisodeRef(this.episodeId, {this.seriesContext});

  @override
  String get id => episodeId;

  @override
  bool operator ==(Object other) =>
      other is PlayerEpisodeRef &&
      other.episodeId == episodeId &&
      other.seriesContext == seriesContext;

  @override
  int get hashCode => Object.hash(episodeId, seriesContext);
}
