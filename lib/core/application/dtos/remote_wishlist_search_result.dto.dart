import 'package:kidflix/core/domain/model/wishlist_entry.dart';
import 'package:kidflix/core/domain/model/wishlist_search_result.dart';

/// Wire-format DTO for one entry of the `GET /wishlist/search`
/// response, after kidflix-api has normalised the upstream Watcharr
/// payload (`/api/search`) by filtering out non-media kinds and
/// computing the catalog crossing.
///
/// Shape (cf. `WATCHARR_WISHLIST_FEATURE.md § /wishlist/search`):
///
/// ```json
/// {
///   "tmdb_id": 12345,
///   "kind": "movie" | "series",
///   "title": "...",
///   "year": 2013,
///   "poster_url": "https://image.tmdb.org/t/p/w500/...",
///   "available_in_catalog": false,
///   "catalog_kind": null,
///   "catalog_id": null,
///   "already_in_wishlist": false
/// }
/// ```
///
/// As for [RemoteWishlistEntryDto], `catalog_kind` is validated but
/// discarded on projection — it always equals `kind` when present.
class RemoteWishlistSearchResultDto {
  final int tmdbId;
  final WishlistItemKind kind;
  final String title;
  final int? year;
  final String? posterUrl;
  final bool availableInCatalog;
  final String? catalogId;
  final bool alreadyInWishlist;

  const RemoteWishlistSearchResultDto({
    required this.tmdbId,
    required this.kind,
    required this.title,
    required this.availableInCatalog,
    required this.alreadyInWishlist,
    this.year,
    this.posterUrl,
    this.catalogId,
  });

  factory RemoteWishlistSearchResultDto.fromJson(Map<String, dynamic> json) =>
      RemoteWishlistSearchResultDto(
        tmdbId: json['tmdb_id'] as int,
        kind: _kindFromWire(json['kind'] as String),
        title: json['title'] as String,
        year: json['year'] as int?,
        posterUrl: json['poster_url'] as String?,
        availableInCatalog: json['available_in_catalog'] as bool,
        catalogId: json['catalog_id'] as String?,
        alreadyInWishlist: json['already_in_wishlist'] as bool,
      );

  WishlistSearchResult toDomain() => WishlistSearchResult(
    tmdbId: tmdbId,
    kind: kind,
    title: title,
    year: year,
    posterUrl: posterUrl,
    availableInCatalog: availableInCatalog,
    catalogId: catalogId,
    alreadyInWishlist: alreadyInWishlist,
  );
}

WishlistItemKind _kindFromWire(String wire) {
  switch (wire) {
    case 'movie':
      return WishlistItemKind.movie;
    case 'series':
      return WishlistItemKind.series;
    default:
      throw FormatException('Unknown wishlist search kind: $wire');
  }
}

/// Wire counterpart for [WishlistItemKind] — mirrors the constant used
/// by the wishlist add endpoint (`POST /wishlist`) so the repository
/// implementations don't reinvent it for each call site.
String wishlistKindToWire(WishlistItemKind kind) {
  switch (kind) {
    case WishlistItemKind.movie:
      return 'movie';
    case WishlistItemKind.series:
      return 'series';
  }
}
