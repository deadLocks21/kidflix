import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kidflix/core/application/dtos/wishlist_entry.dto.dart';
import 'package:kidflix/core/domain/model/wishlist_entry.dart';
import 'package:kidflix/infrastructure/providers/wishlist.controller_provider.dart';

/// Modal bottom sheet shown when the parent long-presses a wishlist
/// card. Offers two destructive actions:
///
/// - **Marquer comme vu** — `PUT /wishlist/{id}/status` with
///   `FINISHED`. The entry stays in the list (Watcharr doesn't drop
///   finished entries) but sinks to the bottom of the sort.
/// - **Retirer de la liste** — `DELETE /wishlist/{id}`. The entry
///   disappears from Watcharr entirely.
///
/// Both go through [WishlistController] for optimistic mutation. A
/// SnackBar surfaces success / failure ; on failure, the controller
/// has already rolled back the local state.
Future<void> showWishlistEntryActionsSheet(
  BuildContext context, {
  required WishlistEntryDto entry,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (_) => _ActionsSheet(entry: entry),
  );
}

class _ActionsSheet extends ConsumerWidget {
  final WishlistEntryDto entry;

  const _ActionsSheet({required this.entry});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isAlreadyFinished = entry.status == WatchedStatus.finished;
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
            child: Text(
              entry.title,
              style: theme.textTheme.titleMedium,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (!isAlreadyFinished)
            ListTile(
              leading: const Icon(Icons.check_circle_outline),
              title: const Text('Marquer comme vu'),
              onTap: () => _markAsWatched(context, ref),
            ),
          ListTile(
            leading: const Icon(Icons.delete_outline),
            title: const Text('Retirer de la liste'),
            onTap: () => _remove(context, ref),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Future<void> _markAsWatched(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    navigator.pop();
    try {
      await ref
          .read(wishlistControllerProvider.notifier)
          .markAsWatched(entry.watcharrId);
      messenger.showSnackBar(
        SnackBar(content: Text('« ${entry.title} » marqué comme vu')),
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Impossible de marquer comme vu')),
      );
    }
  }

  Future<void> _remove(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    navigator.pop();
    try {
      await ref
          .read(wishlistControllerProvider.notifier)
          .remove(entry.watcharrId);
      messenger.showSnackBar(
        SnackBar(content: Text('« ${entry.title} » retiré de la liste')),
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Impossible de retirer')),
      );
    }
  }
}
