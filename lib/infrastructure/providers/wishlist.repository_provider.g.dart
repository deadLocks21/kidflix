// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'wishlist.repository_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
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

@ProviderFor(wishlistRepository)
final wishlistRepositoryProvider = WishlistRepositoryProvider._();

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

final class WishlistRepositoryProvider
    extends
        $FunctionalProvider<
          WishlistRepository,
          WishlistRepository,
          WishlistRepository
        >
    with $Provider<WishlistRepository> {
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
  WishlistRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'wishlistRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$wishlistRepositoryHash();

  @$internal
  @override
  $ProviderElement<WishlistRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  WishlistRepository create(Ref ref) {
    return wishlistRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(WishlistRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<WishlistRepository>(value),
    );
  }
}

String _$wishlistRepositoryHash() =>
    r'c25db776b4692a2a2f3ea71a65658d7129a737c9';
