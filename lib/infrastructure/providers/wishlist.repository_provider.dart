import 'package:kidflix/core/domain/services/wishlist.repository.dart';
import 'package:kidflix/infrastructure/providers/api_base_url.provider.dart';
import 'package:kidflix/infrastructure/providers/dio.provider.dart';
import 'package:kidflix/infrastructure/wishlist/dio.wishlist.repository.dart';
import 'package:kidflix/infrastructure/wishlist/in_memory.wishlist.repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'wishlist.repository_provider.g.dart';

/// Wishlist repository provider.
///
/// - **empty / demo URL** → [InMemoryWishlistRepository] with a few
///   fixture entries so the parent-only wishlist page is exercisable
///   in dev / web mode.
/// - **real URL** → [DioWishlistRepository] hitting the
///   `/wishlist*` endpoints proxied by kidflix-api on top of the
///   foyer's Watcharr account (cf. `WATCHARR_WISHLIST_FEATURE.md`).
///
/// `keepAlive` so the in-memory variant survives across navigations —
/// otherwise a mutation made from the wishlist page would not be
/// visible after navigating away and back.
@Riverpod(keepAlive: true)
WishlistRepository wishlistRepository(Ref ref) {
  final baseUrl = ref.watch(apiBaseUrlProvider);
  if (isInMemoryBaseUrl(baseUrl)) {
    return InMemoryWishlistRepository();
  }
  return DioWishlistRepository(dio: ref.watch(dioProvider));
}
