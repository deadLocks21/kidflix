import 'package:kidflix/core/domain/model/wishlist_entry.dart';
import 'package:kidflix/core/domain/model/wishlist_search_result.dart';

/// UI-facing projection of a [WishlistSearchResult].
///
/// Same fields as the Domain entity. Two convenience getters
/// ([canBeAdded], [hintLabel]) live here so the UI doesn't reach into
/// the Domain to derive them.
class WishlistSearchResultDto {
  final int tmdbId;
  final WishlistItemKind kind;
  final String title;
  final int? year;
  final String? posterUrl;
  final bool availableInCatalog;
  final String? catalogId;
  final bool alreadyInWishlist;

  const WishlistSearchResultDto({
    required this.tmdbId,
    required this.kind,
    required this.title,
    required this.availableInCatalog,
    required this.alreadyInWishlist,
    this.year,
    this.posterUrl,
    this.catalogId,
  });

  factory WishlistSearchResultDto.fromDomain(WishlistSearchResult r) =>
      WishlistSearchResultDto(
        tmdbId: r.tmdbId,
        kind: r.kind,
        title: r.title,
        year: r.year,
        posterUrl: r.posterUrl,
        availableInCatalog: r.availableInCatalog,
        catalogId: r.catalogId,
        alreadyInWishlist: r.alreadyInWishlist,
      );

  /// `true` when the parent can still trigger an add. Already-in-list
  /// items can't (Watcharr would 403) ; already-in-catalog items
  /// **can** (the wishlist filter would hide them anyway, but the
  /// parent might want to keep a record).
  bool get canBeAdded => !alreadyInWishlist;

  /// Optional informational label rendered below the title. `null`
  /// when there's nothing to flag.
  String? get hintLabel {
    if (alreadyInWishlist) return 'Déjà dans la liste';
    if (availableInCatalog) return 'Déjà dans la médiathèque';
    return null;
  }
}
