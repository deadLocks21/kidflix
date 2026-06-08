import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kidflix/infrastructure/providers/seen.controller_provider.dart';

/// Toggle button on the movie detail modal for the active profile's
/// "Déjà vu" mark on [movieId].
///
/// State rendering :
///
/// - Not seen → `Icons.visibility_outlined`, tooltip "Marquer déjà vu".
/// - Seen → `Icons.visibility`, tinted, tooltip "Pas encore vu".
/// - Controller still loading → button disabled.
///
/// On tap, the [SeenController] does an optimistic update + repo
/// roundtrip. On failure the controller reverts state and rethrows ; we
/// catch the exception and surface a snackbar so the user can retry.
class SeenButton extends ConsumerWidget {
  final String movieId;

  const SeenButton({super.key, required this.movieId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncSeen = ref.watch(seenControllerProvider);
    final theme = Theme.of(context);
    final seen = asyncSeen.maybeWhen(
      data: (list) => list.any((m) => m.movieId == movieId),
      orElse: () => false,
    );
    final loading = asyncSeen.isLoading && !asyncSeen.hasValue;
    return IconButton(
      tooltip: seen ? 'Pas encore vu' : 'Marquer comme déjà vu',
      icon: Icon(
        seen ? Icons.visibility : Icons.visibility_outlined,
        color: seen ? theme.colorScheme.primary : null,
      ),
      onPressed: loading ? null : () => _onTap(context, ref, seen),
    );
  }

  Future<void> _onTap(
    BuildContext context,
    WidgetRef ref,
    bool currentlySeen,
  ) async {
    final controller = ref.read(seenControllerProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);
    try {
      if (currentlySeen) {
        await controller.unmarkSeen(movieId);
      } else {
        await controller.markSeen(movieId);
      }
    } catch (_) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            currentlySeen
                ? 'Impossible de retirer des déjà-vus'
                : 'Impossible de marquer comme déjà vu',
          ),
        ),
      );
    }
  }
}
