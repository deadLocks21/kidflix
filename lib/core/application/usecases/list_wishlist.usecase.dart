import 'package:kidflix/core/application/dtos/wishlist_entry.dto.dart';
import 'package:kidflix/core/domain/model/wishlist_entry.dart';
import 'package:kidflix/core/domain/services/wishlist.repository.dart';

/// Fetches the foyer's wishlist, applies the parent-only "à acquérir"
/// filter, and projects each survivor to its UI DTO.
///
/// The filter surfaces **films et séries à voir qui ne sont pas encore
/// dans la médiathèque**. Everything else is noise for the parent's
/// workflow:
///
/// - `availableInCatalog == false` — once an item lands in the
///   kdrive, kids can find it on the home like any other content ;
///   keeping it here would duplicate the catalog.
/// - `status == planned` — `watching` / `hold` / `finished` /
///   `dropped` are non-actionable from this view. The parent keeps
///   them in Watcharr for tracking, but the home menu shortcut
///   focuses on the "à voir" backlog.
///
/// Both `kind == movie` and `kind == series` pass through — a series
/// the family wants in the médiathèque is just as relevant as a film.
///
/// Result is sorted alphabetically by title (case-insensitive).
class ListWishlistUseCase {
  final WishlistRepository _repo;

  const ListWishlistUseCase(this._repo);

  Future<List<WishlistEntryDto>> execute() async {
    final entries = await _repo.list();
    final filtered = entries.where(_keepEntry).toList()..sort(_compare);
    return filtered
        .map(WishlistEntryDto.fromDomain)
        .toList(growable: false);
  }

  bool _keepEntry(WishlistEntry entry) =>
      !entry.availableInCatalog &&
      entry.status == WatchedStatus.planned;

  int _compare(WishlistEntry a, WishlistEntry b) =>
      a.title.toLowerCase().compareTo(b.title.toLowerCase());
}
