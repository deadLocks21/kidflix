import 'package:flutter/foundation.dart';
import 'package:kidflix/core/application/session_state.dart';
import 'package:kidflix/core/domain/model/favorite.dart';
import 'package:kidflix/core/domain/services/favorites.repository.dart';
import 'package:kidflix/infrastructure/providers/favorites.repository_provider.dart';
import 'package:kidflix/infrastructure/providers/session.controller_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'favorites.controller_provider.g.dart';

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
@Riverpod(keepAlive: true)
class FavoritesController extends _$FavoritesController {
  @override
  Future<List<Favorite>> build() async {
    final session = ref.watch(sessionControllerProvider);
    if (session is! ProfileSelected) return const [];
    final repo = ref.watch(favoritesRepositoryProvider);
    return repo.listForProfile(session.profile.id);
  }

  Future<void> addMovie(String movieId) =>
      _mutate((repo, profileId, current) async {
        final optimistic = [
          ...current.where(
            (f) => !(f is MovieFavorite && f.movieId == movieId),
          ),
          MovieFavorite(
            profileId: profileId,
            movieId: movieId,
            createdAt: DateTime.now().toUtc(),
          ),
        ];
        state = AsyncData(optimistic);
        await repo.addMovie(profileId: profileId, movieId: movieId);
      });

  Future<void> removeMovie(String movieId) =>
      _mutate((repo, profileId, current) async {
        final optimistic = current
            .where((f) => !(f is MovieFavorite && f.movieId == movieId))
            .toList(growable: false);
        state = AsyncData(optimistic);
        await repo.removeMovie(profileId: profileId, movieId: movieId);
      });

  Future<void> addSeries(String seriesId) =>
      _mutate((repo, profileId, current) async {
        final optimistic = [
          ...current.where(
            (f) => !(f is SeriesFavorite && f.seriesId == seriesId),
          ),
          SeriesFavorite(
            profileId: profileId,
            seriesId: seriesId,
            createdAt: DateTime.now().toUtc(),
          ),
        ];
        state = AsyncData(optimistic);
        await repo.addSeries(profileId: profileId, seriesId: seriesId);
      });

  Future<void> removeSeries(String seriesId) =>
      _mutate((repo, profileId, current) async {
        final optimistic = current
            .where((f) => !(f is SeriesFavorite && f.seriesId == seriesId))
            .toList(growable: false);
        state = AsyncData(optimistic);
        await repo.removeSeries(profileId: profileId, seriesId: seriesId);
      });

  Future<void> _mutate(
    Future<void> Function(
      FavoritesRepository repo,
      String profileId,
      List<Favorite> current,
    ) action,
  ) async {
    final session = ref.read(sessionControllerProvider);
    if (session is! ProfileSelected) {
      debugPrint(
        '[kidflix.favorites] mutation skipped: no active profile '
        '(session=${session.runtimeType})',
      );
      return;
    }
    final profileId = session.profile.id;
    final repo = ref.read(favoritesRepositoryProvider);
    debugPrint(
      '[kidflix.favorites] mutation start (profileId=$profileId, '
      'repo=${repo.runtimeType})',
    );
    final previous = state.value ?? const <Favorite>[];
    try {
      await action(repo, profileId, previous);
      // Re-fetch from the repository so we settle on the server-truth
      // (e.g. `createdAt` of an already-present entry isn't refreshed
      // server-side — the optimistic value we wrote would mislead the
      // rail's sort otherwise). Downstream `homeCatalogRows` watches
      // this controller, so it auto-invalidates when state changes —
      // no explicit `ref.invalidate` needed.
      state = AsyncData(await repo.listForProfile(profileId));
      debugPrint('[kidflix.favorites] mutation succeeded');
    } catch (e, st) {
      debugPrint(
        '[kidflix.favorites] mutation failed, reverting state\n'
        'error: $e\n'
        '$st',
      );
      state = AsyncData(previous);
      rethrow;
    }
  }
}
