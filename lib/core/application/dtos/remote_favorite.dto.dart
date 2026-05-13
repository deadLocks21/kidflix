import 'package:kidflix/core/domain/model/favorite.dart';

/// Parses a single wire entry of `/profiles/{p}/favorites` into a
/// Domain [Favorite].
///
/// The wire shape (cf. `FAVORITES_FEATURE.md`):
///
/// ```json
/// {
///   "kind": "movie" | "series",
///   "profile_id": "...",
///   "media_id": "...",
///   "created_at": "2026-05-12T10:30:00Z"
/// }
/// ```
///
/// Fail-fast on missing or unknown `kind` (FormatException).
Favorite favoriteFromJson(Map<String, dynamic> json) {
  final kind = json['kind'];
  final profileId = json['profile_id'] as String;
  final mediaId = json['media_id'] as String;
  final createdAt = DateTime.parse(json['created_at'] as String);

  switch (kind) {
    case 'movie':
      return MovieFavorite(
        profileId: profileId,
        movieId: mediaId,
        createdAt: createdAt,
      );
    case 'series':
      return SeriesFavorite(
        profileId: profileId,
        seriesId: mediaId,
        createdAt: createdAt,
      );
    default:
      throw FormatException('Unknown favorite kind: $kind');
  }
}
