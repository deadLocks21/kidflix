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

  /// Constructs a movie reference.
  factory PlayerMediaRef.movie(String movieId) = PlayerMovieRef;

  /// Constructs an episode reference.
  factory PlayerMediaRef.episode(String episodeId) = PlayerEpisodeRef;
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

  const PlayerEpisodeRef(this.episodeId);

  @override
  String get id => episodeId;

  @override
  bool operator ==(Object other) =>
      other is PlayerEpisodeRef && other.episodeId == episodeId;

  @override
  int get hashCode => episodeId.hashCode;
}
