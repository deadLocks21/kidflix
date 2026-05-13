import 'package:kidflix/core/domain/model/wishlist_entry.dart';

/// One row in the search results when the parent looks for something
/// to add to the foyer's Watcharr wishlist.
///
/// Unlike [WishlistEntry], a [WishlistSearchResult] is **not** in the
/// wishlist yet — it represents a TMDB item the parent might or might
/// not decide to add. The two are deliberately separate types so the
/// UI can't mistake one for the other (e.g. no `watcharrId` exposed
/// since the entry doesn't have one until it's added).
///
/// `availableInCatalog` / `catalogId` are computed server-side, like
/// for wishlist entries, so the UI can warn the parent that the item
/// is already in the kdrive — adding it to Watcharr is still allowed
/// but would create an entry that would be hidden by the "à acquérir"
/// filter anyway. The flag is informational.
///
/// `alreadyInWishlist` flags items already in the foyer's Watcharr
/// list (regardless of status). The UI uses it to disable the "Ajouter"
/// affordance and show a hint instead.
class WishlistSearchResult {
  final int tmdbId;
  final WishlistItemKind kind;
  final String title;
  final int? year;
  final String? posterUrl;
  final bool availableInCatalog;
  final String? catalogId;
  final bool alreadyInWishlist;

  const WishlistSearchResult({
    required this.tmdbId,
    required this.kind,
    required this.title,
    required this.availableInCatalog,
    required this.alreadyInWishlist,
    this.year,
    this.posterUrl,
    this.catalogId,
  });

  /// Identity by `(tmdbId, kind)` — TMDB ids are unique per kind but
  /// can theoretically collide between movies and series.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WishlistSearchResult &&
          other.tmdbId == tmdbId &&
          other.kind == kind);

  @override
  int get hashCode => Object.hash(tmdbId, kind);

  @override
  String toString() =>
      'WishlistSearchResult(tmdbId: $tmdbId, kind: $kind, title: $title, '
      'availableInCatalog: $availableInCatalog, '
      'alreadyInWishlist: $alreadyInWishlist)';
}
