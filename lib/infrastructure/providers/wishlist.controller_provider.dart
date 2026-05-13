import 'package:flutter/foundation.dart';
import 'package:kidflix/core/application/dtos/wishlist_entry.dto.dart';
import 'package:kidflix/core/application/session_state.dart';
import 'package:kidflix/infrastructure/providers/session.controller_provider.dart';
import 'package:kidflix/infrastructure/providers/wishlist.usecases_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'wishlist.controller_provider.g.dart';

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
@Riverpod(keepAlive: true)
class WishlistController extends _$WishlistController {
  @override
  Future<List<WishlistEntryDto>> build() async {
    final session = ref.watch(sessionControllerProvider);
    if (session is! ProfileSelected || !session.profile.isMain) {
      return const [];
    }
    return ref.read(listWishlistUseCaseProvider).execute();
  }

  /// Marks the entry with [watcharrId] as `FINISHED`. The row is
  /// kept in the list (Watcharr doesn't drop FINISHED entries), but
  /// the use case's sort drops it further down.
  Future<void> markAsWatched(int watcharrId) async {
    final previous = state.value ?? const <WishlistEntryDto>[];
    try {
      final updated = await ref
          .read(markWishlistAsWatchedUseCaseProvider)
          .execute(watcharrId);
      final replaced = previous
          .map((e) => e.watcharrId == watcharrId ? updated : e)
          .toList(growable: false);
      state = AsyncData(replaced);
    } catch (e, st) {
      debugPrint(
        '[kidflix.wishlist] mark-as-watched failed (watcharrId=$watcharrId)\n'
        'error: $e\n'
        '$st',
      );
      state = AsyncData(previous);
      rethrow;
    }
  }

  /// Removes the entry with [watcharrId] from Watcharr entirely.
  /// Optimistic: the row disappears immediately ; on failure, the
  /// state is restored and the error rethrown.
  Future<void> remove(int watcharrId) async {
    final previous = state.value ?? const <WishlistEntryDto>[];
    final optimistic = previous
        .where((e) => e.watcharrId != watcharrId)
        .toList(growable: false);
    state = AsyncData(optimistic);
    try {
      await ref.read(removeFromWishlistUseCaseProvider).execute(watcharrId);
    } catch (e, st) {
      debugPrint(
        '[kidflix.wishlist] remove failed (watcharrId=$watcharrId)\n'
        'error: $e\n'
        '$st',
      );
      state = AsyncData(previous);
      rethrow;
    }
  }

  /// Refetches the whole list from the repository. Bound to
  /// pull-to-refresh on the wishlist page.
  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(listWishlistUseCaseProvider).execute(),
    );
  }
}
