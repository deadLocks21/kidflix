// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'seen.controller_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Central controller for the active profile's "Déjà vu" marks.
///
/// Owns the source of truth for the per-film toggle ([SeenButton]) and
/// the bulk entry screen. The home rows provider watches this controller
/// so a mutation re-filters the "Jamais vus" row in one rebuild
/// round-trip — mirroring how [FavoritesController] feeds "Ma liste".
///
/// State semantics:
///
/// - **Loading** until [build] resolves the list for the active profile.
/// - **Empty list** when no profile is selected (anonymous / OTP / pin).
///   The controller does not throw — the UI just sees no marks.
/// - **Refreshed** automatically whenever the active profile changes
///   (`sessionControllerProvider` is watched).
///
/// Mutations are optimistic: [markSeen] / [unmarkSeen] / [markManySeen]
/// update local state immediately, push to the repository in the
/// background, then re-fetch to settle on server-truth. On failure they
/// roll back + rethrow so the caller can surface a snackbar.

@ProviderFor(SeenController)
final seenControllerProvider = SeenControllerProvider._();

/// Central controller for the active profile's "Déjà vu" marks.
///
/// Owns the source of truth for the per-film toggle ([SeenButton]) and
/// the bulk entry screen. The home rows provider watches this controller
/// so a mutation re-filters the "Jamais vus" row in one rebuild
/// round-trip — mirroring how [FavoritesController] feeds "Ma liste".
///
/// State semantics:
///
/// - **Loading** until [build] resolves the list for the active profile.
/// - **Empty list** when no profile is selected (anonymous / OTP / pin).
///   The controller does not throw — the UI just sees no marks.
/// - **Refreshed** automatically whenever the active profile changes
///   (`sessionControllerProvider` is watched).
///
/// Mutations are optimistic: [markSeen] / [unmarkSeen] / [markManySeen]
/// update local state immediately, push to the repository in the
/// background, then re-fetch to settle on server-truth. On failure they
/// roll back + rethrow so the caller can surface a snackbar.
final class SeenControllerProvider
    extends $AsyncNotifierProvider<SeenController, List<SeenMark>> {
  /// Central controller for the active profile's "Déjà vu" marks.
  ///
  /// Owns the source of truth for the per-film toggle ([SeenButton]) and
  /// the bulk entry screen. The home rows provider watches this controller
  /// so a mutation re-filters the "Jamais vus" row in one rebuild
  /// round-trip — mirroring how [FavoritesController] feeds "Ma liste".
  ///
  /// State semantics:
  ///
  /// - **Loading** until [build] resolves the list for the active profile.
  /// - **Empty list** when no profile is selected (anonymous / OTP / pin).
  ///   The controller does not throw — the UI just sees no marks.
  /// - **Refreshed** automatically whenever the active profile changes
  ///   (`sessionControllerProvider` is watched).
  ///
  /// Mutations are optimistic: [markSeen] / [unmarkSeen] / [markManySeen]
  /// update local state immediately, push to the repository in the
  /// background, then re-fetch to settle on server-truth. On failure they
  /// roll back + rethrow so the caller can surface a snackbar.
  SeenControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'seenControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$seenControllerHash();

  @$internal
  @override
  SeenController create() => SeenController();
}

String _$seenControllerHash() => r'66b3cccd93cf053be3e44a3b8adfe30eda594eaf';

/// Central controller for the active profile's "Déjà vu" marks.
///
/// Owns the source of truth for the per-film toggle ([SeenButton]) and
/// the bulk entry screen. The home rows provider watches this controller
/// so a mutation re-filters the "Jamais vus" row in one rebuild
/// round-trip — mirroring how [FavoritesController] feeds "Ma liste".
///
/// State semantics:
///
/// - **Loading** until [build] resolves the list for the active profile.
/// - **Empty list** when no profile is selected (anonymous / OTP / pin).
///   The controller does not throw — the UI just sees no marks.
/// - **Refreshed** automatically whenever the active profile changes
///   (`sessionControllerProvider` is watched).
///
/// Mutations are optimistic: [markSeen] / [unmarkSeen] / [markManySeen]
/// update local state immediately, push to the repository in the
/// background, then re-fetch to settle on server-truth. On failure they
/// roll back + rethrow so the caller can surface a snackbar.

abstract class _$SeenController extends $AsyncNotifier<List<SeenMark>> {
  FutureOr<List<SeenMark>> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AsyncValue<List<SeenMark>>, List<SeenMark>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<List<SeenMark>>, List<SeenMark>>,
              AsyncValue<List<SeenMark>>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
