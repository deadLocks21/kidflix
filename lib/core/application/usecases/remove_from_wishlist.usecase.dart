import 'package:kidflix/core/domain/services/wishlist.repository.dart';

/// Removes an entry from the foyer's Watcharr wishlist.
///
/// The destructive variant of [MarkWishlistAsWatchedUseCase]: the
/// entry disappears from Watcharr entirely, not just changes status.
/// Used from the long-press / bottom-sheet menu when the parent
/// decides the film is no longer wanted.
class RemoveFromWishlistUseCase {
  final WishlistRepository _repo;

  const RemoveFromWishlistUseCase(this._repo);

  Future<void> execute(int watcharrId) => _repo.remove(watcharrId);
}
