import 'package:kidflix/core/domain/model/wishlist_entry.dart';

/// UI-facing projection of a [WishlistEntry].
///
/// Adds a [category] field on top of the Domain shape — the wishlist
/// page renders three sections (à télécharger, à visionner, déjà vu)
/// keyed on it. The use case is responsible for computing the
/// category by cross-referencing the foyer's watch progress.
class WishlistEntryDto {
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
  final WishlistCategory category;

  const WishlistEntryDto({
    required this.watcharrId,
    required this.tmdbId,
    required this.kind,
    required this.title,
    required this.status,
    required this.rating,
    required this.availableInCatalog,
    required this.category,
    this.year,
    this.posterUrl,
    this.catalogId,
  });

  /// Convenience constructor used by call sites that don't enrich
  /// against the watch progress (e.g. the `add` flow before the
  /// next refresh). Defaults the category based on availability only.
  factory WishlistEntryDto.fromDomain(WishlistEntry entry) => WishlistEntryDto(
    watcharrId: entry.watcharrId,
    tmdbId: entry.tmdbId,
    kind: entry.kind,
    title: entry.title,
    year: entry.year,
    posterUrl: entry.posterUrl,
    status: entry.status,
    rating: entry.rating,
    availableInCatalog: entry.availableInCatalog,
    catalogId: entry.catalogId,
    category: entry.availableInCatalog
        ? WishlistCategory.toWatch
        : WishlistCategory.toAcquire,
  );

  /// `true` when the same TMDB item already ships in the local
  /// catalog and a [catalogId] is resolvable to a playable target.
  bool get isAvailable => availableInCatalog && catalogId != null;

  /// The UI surfaces the "Lire" action only on entries that are both
  /// available in the catalog AND for which the resolved item is
  /// playable directly from the wishlist (movies). Series open the
  /// detail modal first, so the wishlist row still routes there.
  bool get showsPlayAction => isAvailable;
}

/// Bucket a wishlist entry falls in, displayed as a section on the
/// wishlist page.
///
/// Computation rule (see [ListWishlistUseCase]) :
///
/// - `toAcquire` — not in the local catalog yet. The parent has
///   flagged the title in Watcharr but kidflix-api's `/catalog`
///   doesn't ship it.
/// - `toWatch` — in the catalog, and nobody in the foyer has
///   completed it yet. For series, all in-catalog entries land here
///   (no aggregate "watched" signal for series in v1).
/// - `watched` — movies only: in the catalog, and at least one
///   profile of the foyer has a `MovieProgress` with
///   `completed == true` for the resolved `catalogId`.
enum WishlistCategory { toAcquire, toWatch, watched }
