import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kidflix/core/domain/model/favorite.dart';
import 'package:kidflix/infrastructure/providers/favorites.controller_provider.dart';

/// Discriminated target for a "Ma liste" toggle. Sealed so the button
/// can switch exhaustively without a default branch — mirrors the
/// shape of the Domain [Favorite] but without `profileId` /
/// `createdAt` (the controller already knows the active profile).
sealed class FavoriteToggleTarget {
  const FavoriteToggleTarget();
}

class MovieFavoriteTarget extends FavoriteToggleTarget {
  final String movieId;

  const MovieFavoriteTarget(this.movieId);
}

class SeriesFavoriteTarget extends FavoriteToggleTarget {
  final String seriesId;

  const SeriesFavoriteTarget(this.seriesId);
}

/// Heart icon button used on the movie / series detail modals to toggle
/// the active profile's "Ma liste" entry on the given [target].
///
/// State rendering :
///
/// - Not favorited → `Icons.favorite_border`, tooltip "Ajouter à Ma liste".
/// - Favorited → `Icons.favorite`, tooltip "Retirer de Ma liste".
/// - Controller still loading → button disabled, outlined heart.
///
/// On tap, the [FavoritesController] does an optimistic update + repo
/// roundtrip. On failure the controller reverts state and rethrows ; we
/// catch the exception and surface a snackbar so the user can retry.
class FavoriteButton extends ConsumerWidget {
  final FavoriteToggleTarget target;

  const FavoriteButton({super.key, required this.target});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncFavorites = ref.watch(favoritesControllerProvider);
    final theme = Theme.of(context);
    final favorited = asyncFavorites.maybeWhen(
      data: (list) => _isFavorited(list, target),
      orElse: () => false,
    );
    final loading = asyncFavorites.isLoading && !asyncFavorites.hasValue;
    return IconButton(
      tooltip: favorited ? 'Retirer de Ma liste' : 'Ajouter à Ma liste',
      icon: Icon(
        favorited ? Icons.favorite : Icons.favorite_border,
        color: favorited ? theme.colorScheme.primary : null,
      ),
      onPressed: loading ? null : () => _onTap(context, ref, favorited),
    );
  }

  Future<void> _onTap(
    BuildContext context,
    WidgetRef ref,
    bool currentlyFavorited,
  ) async {
    final controller = ref.read(favoritesControllerProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);
    debugPrint(
      '[kidflix.favorites] button tap (target=$target, '
      'currentlyFavorited=$currentlyFavorited)',
    );
    try {
      switch (target) {
        case MovieFavoriteTarget(:final movieId):
          if (currentlyFavorited) {
            await controller.removeMovie(movieId);
          } else {
            await controller.addMovie(movieId);
          }
        case SeriesFavoriteTarget(:final seriesId):
          if (currentlyFavorited) {
            await controller.removeSeries(seriesId);
          } else {
            await controller.addSeries(seriesId);
          }
      }
    } catch (e, st) {
      debugPrint(
        '[kidflix.favorites] toggle failed (target=$target, '
        'currentlyFavorited=$currentlyFavorited)\n'
        'error: $e\n'
        '$st',
      );
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            currentlyFavorited
                ? 'Impossible de retirer de Ma liste'
                : 'Impossible d\'ajouter à Ma liste',
          ),
        ),
      );
    }
  }

  static bool _isFavorited(
    List<Favorite> list,
    FavoriteToggleTarget target,
  ) {
    return switch (target) {
      MovieFavoriteTarget(:final movieId) =>
        list.any((f) => f is MovieFavorite && f.movieId == movieId),
      SeriesFavoriteTarget(:final seriesId) =>
        list.any((f) => f is SeriesFavorite && f.seriesId == seriesId),
    };
  }
}
