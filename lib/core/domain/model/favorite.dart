/// A profile's "Ma liste" entry on a single media item.
///
/// Two favorites share identity by `(profileId, mediaId)` within their
/// own kind ; `createdAt` is state, not identity. `Favorite` is sealed:
/// it is either a [MovieFavorite] (keyed on `movieId`) or a
/// [SeriesFavorite] (keyed on `seriesId`), mirroring the polymorphic
/// `(profile_id, media_kind, media_id)` schema documented in
/// `FAVORITES_FEATURE.md`. Episodes are intentionally not a kind:
/// favoriting always targets the whole series.
sealed class Favorite {
  String get profileId;
  DateTime get createdAt;
}

class MovieFavorite extends Favorite {
  @override
  final String profileId;
  final String movieId;
  @override
  final DateTime createdAt;

  MovieFavorite({
    required this.profileId,
    required this.movieId,
    required this.createdAt,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MovieFavorite &&
          other.profileId == profileId &&
          other.movieId == movieId);

  @override
  int get hashCode => Object.hash('movie', profileId, movieId);

  @override
  String toString() =>
      'MovieFavorite(profileId: $profileId, movieId: $movieId, '
      'createdAt: $createdAt)';
}

class SeriesFavorite extends Favorite {
  @override
  final String profileId;
  final String seriesId;
  @override
  final DateTime createdAt;

  SeriesFavorite({
    required this.profileId,
    required this.seriesId,
    required this.createdAt,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SeriesFavorite &&
          other.profileId == profileId &&
          other.seriesId == seriesId);

  @override
  int get hashCode => Object.hash('series', profileId, seriesId);

  @override
  String toString() =>
      'SeriesFavorite(profileId: $profileId, seriesId: $seriesId, '
      'createdAt: $createdAt)';
}
