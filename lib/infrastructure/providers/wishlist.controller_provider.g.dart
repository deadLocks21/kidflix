// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'wishlist.controller_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Central controller for the foyer's wishlist entries.
///
/// State semantics:
///
/// - Returns an empty list when no profile is active or when the
///   active profile is not the main one (the wishlist is a parent-
///   only feature). The UI separately checks `isMain` to decide
///   whether to mount the page at all ; this guard avoids loading
///   spurious data when a non-main session somehow lands on the page.
/// - [WishlistNotConfiguredException] surfaces as an AsyncError so
///   the page can render a dedicated empty state.
/// - Mutations are optimistic: [markAsWatched] swaps the row in
///   place, [remove] drops it. On failure, state is restored and the
///   error is rethrown so the caller surfaces a snackbar.

@ProviderFor(WishlistController)
final wishlistControllerProvider = WishlistControllerProvider._();

/// Central controller for the foyer's wishlist entries.
///
/// State semantics:
///
/// - Returns an empty list when no profile is active or when the
///   active profile is not the main one (the wishlist is a parent-
///   only feature). The UI separately checks `isMain` to decide
///   whether to mount the page at all ; this guard avoids loading
///   spurious data when a non-main session somehow lands on the page.
/// - [WishlistNotConfiguredException] surfaces as an AsyncError so
///   the page can render a dedicated empty state.
/// - Mutations are optimistic: [markAsWatched] swaps the row in
///   place, [remove] drops it. On failure, state is restored and the
///   error is rethrown so the caller surfaces a snackbar.
final class WishlistControllerProvider
    extends $AsyncNotifierProvider<WishlistController, List<WishlistEntryDto>> {
  /// Central controller for the foyer's wishlist entries.
  ///
  /// State semantics:
  ///
  /// - Returns an empty list when no profile is active or when the
  ///   active profile is not the main one (the wishlist is a parent-
  ///   only feature). The UI separately checks `isMain` to decide
  ///   whether to mount the page at all ; this guard avoids loading
  ///   spurious data when a non-main session somehow lands on the page.
  /// - [WishlistNotConfiguredException] surfaces as an AsyncError so
  ///   the page can render a dedicated empty state.
  /// - Mutations are optimistic: [markAsWatched] swaps the row in
  ///   place, [remove] drops it. On failure, state is restored and the
  ///   error is rethrown so the caller surfaces a snackbar.
  WishlistControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'wishlistControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$wishlistControllerHash();

  @$internal
  @override
  WishlistController create() => WishlistController();
}

String _$wishlistControllerHash() =>
    r'78beb2df9c533f05598c526b912f6475d6c7e0fe';

/// Central controller for the foyer's wishlist entries.
///
/// State semantics:
///
/// - Returns an empty list when no profile is active or when the
///   active profile is not the main one (the wishlist is a parent-
///   only feature). The UI separately checks `isMain` to decide
///   whether to mount the page at all ; this guard avoids loading
///   spurious data when a non-main session somehow lands on the page.
/// - [WishlistNotConfiguredException] surfaces as an AsyncError so
///   the page can render a dedicated empty state.
/// - Mutations are optimistic: [markAsWatched] swaps the row in
///   place, [remove] drops it. On failure, state is restored and the
///   error is rethrown so the caller surfaces a snackbar.

abstract class _$WishlistController
    extends $AsyncNotifier<List<WishlistEntryDto>> {
  FutureOr<List<WishlistEntryDto>> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref =
        this.ref
            as $Ref<AsyncValue<List<WishlistEntryDto>>, List<WishlistEntryDto>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<List<WishlistEntryDto>>,
                List<WishlistEntryDto>
              >,
              AsyncValue<List<WishlistEntryDto>>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
