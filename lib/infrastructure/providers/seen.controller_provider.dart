import 'package:flutter/foundation.dart';
import 'package:kidflix/core/application/session_state.dart';
import 'package:kidflix/core/domain/model/seen_mark.dart';
import 'package:kidflix/core/domain/services/seen.repository.dart';
import 'package:kidflix/infrastructure/providers/seen.repository_provider.dart';
import 'package:kidflix/infrastructure/providers/session.controller_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'seen.controller_provider.g.dart';

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
@Riverpod(keepAlive: true)
class SeenController extends _$SeenController {
  @override
  Future<List<SeenMark>> build() async {
    final session = ref.watch(sessionControllerProvider);
    if (session is! ProfileSelected) return const [];
    final repo = ref.watch(seenRepositoryProvider);
    return repo.listForProfile(session.profile.id);
  }

  /// Whether [movieId] is currently marked as seen. Reads the resolved
  /// value ; treats unresolved / error states as "not seen".
  bool isSeen(String movieId) {
    final list = state.value ?? const <SeenMark>[];
    return list.any((m) => m.movieId == movieId);
  }

  Future<void> markSeen(String movieId) =>
      _mutate((repo, profileId, current) async {
        final optimistic = [
          ...current.where((m) => m.movieId != movieId),
          SeenMark(
            profileId: profileId,
            movieId: movieId,
            markedAt: DateTime.now().toUtc(),
          ),
        ];
        state = AsyncData(optimistic);
        await repo.markMovie(profileId: profileId, movieId: movieId);
      });

  Future<void> unmarkSeen(String movieId) =>
      _mutate((repo, profileId, current) async {
        final optimistic = current
            .where((m) => m.movieId != movieId)
            .toList(growable: false);
        state = AsyncData(optimistic);
        await repo.unmarkMovie(profileId: profileId, movieId: movieId);
      });

  /// Bulk-marks [movieIds] as seen in a single backend round-trip (the
  /// "saisie en masse" screen). Already-marked ids keep their original
  /// `markedAt`. An empty selection is a no-op.
  Future<void> markManySeen(List<String> movieIds) {
    if (movieIds.isEmpty) return Future.value();
    return _mutate((repo, profileId, current) async {
      final existing = {for (final m in current) m.movieId};
      final now = DateTime.now().toUtc();
      final optimistic = [
        ...current,
        for (final id in movieIds)
          if (!existing.contains(id))
            SeenMark(profileId: profileId, movieId: id, markedAt: now),
      ];
      state = AsyncData(optimistic);
      await repo.markMovies(profileId: profileId, movieIds: movieIds);
    });
  }

  Future<void> _mutate(
    Future<void> Function(
      SeenRepository repo,
      String profileId,
      List<SeenMark> current,
    )
    action,
  ) async {
    final session = ref.read(sessionControllerProvider);
    if (session is! ProfileSelected) {
      debugPrint(
        '[kidflix.seen] mutation skipped: no active profile '
        '(session=${session.runtimeType})',
      );
      return;
    }
    final profileId = session.profile.id;
    final repo = ref.read(seenRepositoryProvider);
    final previous = state.value ?? const <SeenMark>[];
    try {
      await action(repo, profileId, previous);
      // Re-fetch so we settle on server-truth (e.g. `markedAt` of an
      // already-present entry isn't refreshed server-side). Downstream
      // `homeCatalogRows` watches this controller, so it auto-invalidates
      // when state changes — no explicit `ref.invalidate` needed.
      state = AsyncData(await repo.listForProfile(profileId));
    } catch (e, st) {
      debugPrint('[kidflix.seen] mutation failed, reverting state\n$e\n$st');
      state = AsyncData(previous);
      rethrow;
    }
  }
}
