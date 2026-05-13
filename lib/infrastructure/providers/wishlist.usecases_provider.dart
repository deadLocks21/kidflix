import 'package:kidflix/core/application/usecases/list_wishlist.usecase.dart';
import 'package:kidflix/core/application/usecases/mark_wishlist_as_watched.usecase.dart';
import 'package:kidflix/core/application/usecases/remove_from_wishlist.usecase.dart';
import 'package:kidflix/infrastructure/providers/wishlist.repository_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'wishlist.usecases_provider.g.dart';

@Riverpod(keepAlive: true)
ListWishlistUseCase listWishlistUseCase(Ref ref) {
  return ListWishlistUseCase(ref.watch(wishlistRepositoryProvider));
}

@Riverpod(keepAlive: true)
MarkWishlistAsWatchedUseCase markWishlistAsWatchedUseCase(Ref ref) {
  return MarkWishlistAsWatchedUseCase(ref.watch(wishlistRepositoryProvider));
}

@Riverpod(keepAlive: true)
RemoveFromWishlistUseCase removeFromWishlistUseCase(Ref ref) {
  return RemoveFromWishlistUseCase(ref.watch(wishlistRepositoryProvider));
}
