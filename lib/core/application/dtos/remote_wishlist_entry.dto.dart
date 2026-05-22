import 'package:kidflix/core/domain/model/wishlist_entry.dart';

/// Wire-format DTO for one entry of the `GET /wishlist` response.
///
/// Direction of flow: `JSON → Domain` for [list], `JSON → Domain` for
/// the echo of `PUT /wishlist/{id}/status`. The client never serialises
/// entries back to the server (mutations send only the few fields they
/// need — handled in the repository directly).
///
/// Shape, per `WATCHARR_WISHLIST_FEATURE.md`:
///
/// ```json
/// {
///   "watcharr_id": 42,
///   "tmdb_id": 1399,
///   "kind": "movie" | "series",
///   "title": "...",
///   "year": 2011,
///   "poster_url": "https://image.tmdb.org/t/p/w500/...",
///   "status": "PLANNED" | "WATCHING" | "FINISHED" | "HOLD" | "DROPPED",
///   "rating": 0,
///   "available_in_catalog": false,
///   "catalog_kind": null,
///   "catalog_id": null
/// }
/// ```
///
/// `catalog_kind` is parsed and validated but discarded on projection
/// to Domain: it is always equal to `kind` when `available_in_catalog`
/// is true, so the Domain entry doesn't carry it twice.
class RemoteWishlistEntryDto {
  final int watcharrId;
  final int tmdbId;
  final WishlistItemKind kind;
  final String title;
  final int? year;
  final String? posterUrl;
  final WatchedStatus status;
  final int rating;
  final bool availableInCatalog;
  final String? catalogId;

  const RemoteWishlistEntryDto({
    required this.watcharrId,
    required this.tmdbId,
    required this.kind,
    required this.title,
    required this.status,
    required this.rating,
    required this.availableInCatalog,
    this.year,
    this.posterUrl,
    this.catalogId,
  });

  factory RemoteWishlistEntryDto.fromJson(Map<String, dynamic> json) =>
      RemoteWishlistEntryDto(
        watcharrId: json['watcharr_id'] as int,
        tmdbId: json['tmdb_id'] as int,
        kind: _kindFromWire(json['kind'] as String),
        title: json['title'] as String,
        year: json['year'] as int?,
        posterUrl: json['poster_url'] as String?,
        status: _statusFromWire(json['status'] as String),
        rating: json['rating'] as int,
        availableInCatalog: json['available_in_catalog'] as bool,
        catalogId: json['catalog_id'] as String?,
      );

  WishlistEntry toDomain() => WishlistEntry(
    watcharrId: watcharrId,
    tmdbId: tmdbId,
    kind: kind,
    title: title,
    year: year,
    posterUrl: posterUrl,
    status: status,
    rating: rating,
    availableInCatalog: availableInCatalog,
    catalogId: catalogId,
  );
}

WishlistItemKind _kindFromWire(String wire) {
  switch (wire) {
    case 'movie':
      return WishlistItemKind.movie;
    case 'series':
      return WishlistItemKind.series;
    default:
      throw FormatException('Unknown wishlist kind: $wire');
  }
}

WatchedStatus _statusFromWire(String wire) {
  switch (wire) {
    case 'PLANNED':
      return WatchedStatus.planned;
    case 'WATCHING':
      return WatchedStatus.watching;
    case 'FINISHED':
      return WatchedStatus.finished;
    case 'HOLD':
      return WatchedStatus.hold;
    case 'DROPPED':
      return WatchedStatus.dropped;
    default:
      throw FormatException('Unknown wishlist status: $wire');
  }
}

/// Translates a Domain [WatchedStatus] to its wire-format counterpart,
/// used by the repository when sending `PUT /wishlist/{id}/status`.
String watchedStatusToWire(WatchedStatus status) {
  switch (status) {
    case WatchedStatus.planned:
      return 'PLANNED';
    case WatchedStatus.watching:
      return 'WATCHING';
    case WatchedStatus.finished:
      return 'FINISHED';
    case WatchedStatus.hold:
      return 'HOLD';
    case WatchedStatus.dropped:
      return 'DROPPED';
  }
}
