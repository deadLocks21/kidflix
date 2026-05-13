import 'package:kidflix/core/application/dtos/wishlist_search_result.dto.dart';
import 'package:kidflix/core/domain/services/wishlist.repository.dart';

/// Searches Watcharr (via kidflix-api) for movies and series matching
/// a query, and projects the result list to UI DTOs.
///
/// Empty / too-short queries short-circuit to an empty list rather
/// than hitting the network — the search page calls this on every
/// keystroke (debounced) and would otherwise spam the proxy with
/// noise. Threshold: 2 chars after trim, same as the existing catalog
/// search (`searchMovies.usecase.dart`).
class SearchAddableWishlistContentUseCase {
  static const int minQueryLength = 2;

  final WishlistRepository _repo;

  const SearchAddableWishlistContentUseCase(this._repo);

  Future<List<WishlistSearchResultDto>> execute(String query) async {
    final trimmed = query.trim();
    if (trimmed.length < minQueryLength) {
      return const [];
    }
    final results = await _repo.search(trimmed);
    return results
        .map(WishlistSearchResultDto.fromDomain)
        .toList(growable: false);
  }
}
