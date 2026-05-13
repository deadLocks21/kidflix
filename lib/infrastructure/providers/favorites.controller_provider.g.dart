// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'favorites.controller_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Central controller for the active profile's "Ma liste" entries.
///
/// Owns the source of truth for both the detail-modal toggle button
/// (which renders the favorited state) and the home "Ma liste" rail
/// (which iterates the list). Both consumers `ref.watch` this provider
/// so a mutation triggers a single rebuild round-trip across the UI.
///
/// State semantics:
///
/// - **Loading** until [build] resolves the list for the active profile.
/// - **Empty list** when no profile is selected (anonymous / OTP / pin
///   states). The controller does not throw — the UI just sees no
///   favorites.
/// - **Refreshed** automatically whenever the active profile changes
///   (`sessionControllerProvider` is watched).
///
/// Mutations are optimistic: [addMovie] / [removeMovie] / [addSeries] /
/// [removeSeries] update the local state immediately, push to the
/// repository in the background, and roll back + rethrow on failure so
/// the caller can surface a snackbar. The home rail is invalidated on
/// success so the "Ma liste" row picks up the change.

@ProviderFor(FavoritesController)
final favoritesControllerProvider = FavoritesControllerProvider._();

/// Central controller for the active profile's "Ma liste" entries.
///
/// Owns the source of truth for both the detail-modal toggle button
/// (which renders the favorited state) and the home "Ma liste" rail
/// (which iterates the list). Both consumers `ref.watch` this provider
/// so a mutation triggers a single rebuild round-trip across the UI.
///
/// State semantics:
///
/// - **Loading** until [build] resolves the list for the active profile.
/// - **Empty list** when no profile is selected (anonymous / OTP / pin
///   states). The controller does not throw — the UI just sees no
///   favorites.
/// - **Refreshed** automatically whenever the active profile changes
///   (`sessionControllerProvider` is watched).
///
/// Mutations are optimistic: [addMovie] / [removeMovie] / [addSeries] /
/// [removeSeries] update the local state immediately, push to the
/// repository in the background, and roll back + rethrow on failure so
/// the caller can surface a snackbar. The home rail is invalidated on
/// success so the "Ma liste" row picks up the change.
final class FavoritesControllerProvider
    extends $AsyncNotifierProvider<FavoritesController, List<Favorite>> {
  /// Central controller for the active profile's "Ma liste" entries.
  ///
  /// Owns the source of truth for both the detail-modal toggle button
  /// (which renders the favorited state) and the home "Ma liste" rail
  /// (which iterates the list). Both consumers `ref.watch` this provider
  /// so a mutation triggers a single rebuild round-trip across the UI.
  ///
  /// State semantics:
  ///
  /// - **Loading** until [build] resolves the list for the active profile.
  /// - **Empty list** when no profile is selected (anonymous / OTP / pin
  ///   states). The controller does not throw — the UI just sees no
  ///   favorites.
  /// - **Refreshed** automatically whenever the active profile changes
  ///   (`sessionControllerProvider` is watched).
  ///
  /// Mutations are optimistic: [addMovie] / [removeMovie] / [addSeries] /
  /// [removeSeries] update the local state immediately, push to the
  /// repository in the background, and roll back + rethrow on failure so
  /// the caller can surface a snackbar. The home rail is invalidated on
  /// success so the "Ma liste" row picks up the change.
  FavoritesControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'favoritesControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$favoritesControllerHash();

  @$internal
  @override
  FavoritesController create() => FavoritesController();
}

String _$favoritesControllerHash() =>
    r'2284a87dc3f7fc38677c961952bd126e7c399d60';

/// Central controller for the active profile's "Ma liste" entries.
///
/// Owns the source of truth for both the detail-modal toggle button
/// (which renders the favorited state) and the home "Ma liste" rail
/// (which iterates the list). Both consumers `ref.watch` this provider
/// so a mutation triggers a single rebuild round-trip across the UI.
///
/// State semantics:
///
/// - **Loading** until [build] resolves the list for the active profile.
/// - **Empty list** when no profile is selected (anonymous / OTP / pin
///   states). The controller does not throw — the UI just sees no
///   favorites.
/// - **Refreshed** automatically whenever the active profile changes
///   (`sessionControllerProvider` is watched).
///
/// Mutations are optimistic: [addMovie] / [removeMovie] / [addSeries] /
/// [removeSeries] update the local state immediately, push to the
/// repository in the background, and roll back + rethrow on failure so
/// the caller can surface a snackbar. The home rail is invalidated on
/// success so the "Ma liste" row picks up the change.

abstract class _$FavoritesController extends $AsyncNotifier<List<Favorite>> {
  FutureOr<List<Favorite>> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AsyncValue<List<Favorite>>, List<Favorite>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<List<Favorite>>, List<Favorite>>,
              AsyncValue<List<Favorite>>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
