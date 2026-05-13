import 'package:kidflix/core/application/dtos/wishlist_entry.dto.dart';
import 'package:kidflix/core/domain/model/wishlist_entry.dart';
import 'package:kidflix/core/domain/services/wishlist.repository.dart';

/// Adds a TMDB item to the foyer's Watcharr wishlist, with status
/// `PLANNED` (the only status the Kidflix add surface targets — the
/// other statuses are reachable through Watcharr's own UI).
///
/// Returns the newly-created entry as projected to the UI DTO so the
/// controller can splice it into its local state without re-fetching
/// the whole list.
class AddToWishlistUseCase {
  final WishlistRepository _repo;

  const AddToWishlistUseCase(this._repo);

  Future<WishlistEntryDto> execute({
    required int tmdbId,
    required WishlistItemKind kind,
  }) async {
    final created = await _repo.add(tmdbId: tmdbId, kind: kind);
    return WishlistEntryDto.fromDomain(created);
  }
}
