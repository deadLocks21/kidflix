import 'package:kidflix/core/domain/model/wishlist_entry.dart';

/// UI-facing projection of a [WishlistEntry].
///
/// Same fields as the Domain entity — the UI doesn't need extra
/// derivations beyond what the Domain already exposes. The DTO exists
/// only to keep the layered convention "UI never sees Domain entities"
/// per `project_architecture` memory and the project README.
///
/// Two convenience getters live here: [isAvailable] and
/// [showsPlayAction] — they are pure projections of fields already on
/// the entity, kept in the DTO so the UI doesn't reach back into the
/// Domain to compute them.
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

  const WishlistEntryDto({
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
