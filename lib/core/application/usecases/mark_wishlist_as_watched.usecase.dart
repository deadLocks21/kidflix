import 'package:kidflix/core/application/dtos/wishlist_entry.dto.dart';
import 'package:kidflix/core/domain/model/wishlist_entry.dart';
import 'package:kidflix/core/domain/services/wishlist.repository.dart';

/// Marks a wishlist entry as `FINISHED` on Watcharr.
///
/// The parent triggers this from the long-press / bottom-sheet on a
/// wishlist row, typically after watching a film that just landed in
/// the catalog. The Watcharr-side wishlist UI then shows the entry as
/// "vu" — keeping the source of truth in Watcharr.
///
/// Returns the updated entry as echoed by the server (with catalog
/// crossing refreshed) so the controller can swap the row in place
/// without re-fetching the whole list.
class MarkWishlistAsWatchedUseCase {
  final WishlistRepository _repo;

  const MarkWishlistAsWatchedUseCase(this._repo);

  Future<WishlistEntryDto> execute(int watcharrId) async {
    final updated = await _repo.updateStatus(
      watcharrId: watcharrId,
      status: WatchedStatus.finished,
    );
    return WishlistEntryDto.fromDomain(updated);
  }
}
