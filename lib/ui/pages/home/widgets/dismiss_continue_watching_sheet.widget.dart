import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kidflix/core/application/dtos/continue_watching_card.dto.dart';
import 'package:kidflix/core/application/session_state.dart';
import 'package:kidflix/infrastructure/providers/catalog.usecases_provider.dart';
import 'package:kidflix/infrastructure/providers/session.controller_provider.dart';
import 'package:kidflix/infrastructure/providers/watch_progress.usecases_provider.dart';

/// Modal bottom sheet shown when the user long-presses a card in the
/// Continue Watching row. Offers a single action: "Retirer de Continuer
/// à regarder", which calls [DismissContinueWatchingUseCase] and
/// invalidates `homeCatalogRows` so the row refreshes without the
/// dismissed item.
///
/// A SnackBar is shown after success ; on error, a different SnackBar
/// surfaces a generic "réessayer" message — the dismiss isn't critical
/// and isn't worth a blocking dialog.
Future<void> showDismissContinueWatchingSheet(
  BuildContext context, {
  required ContinueWatchingCardDto card,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => _DismissSheet(card: card),
  );
}

class _DismissSheet extends ConsumerWidget {
  final ContinueWatchingCardDto card;

  const _DismissSheet({required this.card});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
            child: Text(
              card.inner.title,
              style: theme.textTheme.titleMedium,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          ListTile(
            leading: const Icon(Icons.remove_circle_outline),
            title: const Text('Retirer de Continuer à regarder'),
            onTap: () => _onDismiss(context, ref),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Future<void> _onDismiss(BuildContext context, WidgetRef ref) async {
    final session = ref.read(sessionControllerProvider);
    if (session is! ProfileSelected) {
      Navigator.of(context).pop();
      return;
    }
    final useCase = ref.read(dismissContinueWatchingUseCaseProvider);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    navigator.pop();
    try {
      await useCase.execute(
        profileId: session.profile.id,
        target: card.dismissTarget,
      );
      ref.invalidate(homeCatalogRowsProvider);
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Impossible de retirer le film')),
      );
    }
  }
}
