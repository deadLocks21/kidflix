import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kidflix/core/application/dtos/wishlist_entry.dto.dart';
import 'package:kidflix/core/domain/exceptions/wishlist_not_configured.exception.dart';
import 'package:kidflix/infrastructure/providers/wishlist.controller_provider.dart';
import 'package:kidflix/ui/pages/wishlist/widgets/wishlist_card.widget.dart';
import 'package:kidflix/ui/router/app_router.dart';

/// Parent-only wishlist page, accessible from the home avatar menu →
/// "Liste d'envies".
///
/// Renders three sections, top to bottom, hiding the empty ones :
///
/// 1. **À télécharger** — entries that aren't in the local catalog
///    yet. The parent uses this list to drive what to add to the
///    kdrive médiathèque.
/// 2. **À visionner** — entries in the catalog that nobody in the
///    foyer has completed yet. Movies render a "Lire" affordance ;
///    series sit here whenever they're available (no aggregate
///    "watched" signal in v1).
/// 3. **Déjà vu** — movies in the catalog that at least one profile
///    has completed (any `MovieProgress.completed == true`).
///
/// Long-press on a row opens a bottom sheet to mark the entry as
/// watched (FINISHED on Watcharr → drops out of the filter) or to
/// remove it from Watcharr entirely. Pull-to-refresh re-hits the
/// proxy.
///
/// Edge cases handled inline :
///
/// - `WishlistNotConfiguredException` (503) → dedicated empty state
///   telling the parent to provision a Watcharr account.
/// - Other errors → generic error card with a refresh button.
/// - Empty buckets → friendly placeholder pointing to the search FAB.
class WishlistPage extends ConsumerWidget {
  const WishlistPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncEntries = ref.watch(wishlistControllerProvider);
    final hideFab =
        asyncEntries.hasError &&
        asyncEntries.error is WishlistNotConfiguredException;
    return Scaffold(
      appBar: AppBar(title: const Text("Liste d'envies")),
      floatingActionButton: hideFab
          ? null
          : FloatingActionButton.extended(
              icon: const Icon(Icons.add),
              label: const Text('Ajouter'),
              onPressed: () => context.push(AppRoutes.settingsWishlistAdd),
            ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () =>
              ref.read(wishlistControllerProvider.notifier).refresh(),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: asyncEntries.when(
                loading: () =>
                    const _Centered(child: CircularProgressIndicator()),
                error: (e, _) => _ErrorView(error: e, ref: ref),
                data: (entries) => _Sections(entries: entries),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Sections extends StatelessWidget {
  final List<WishlistEntryDto> entries;

  const _Sections({required this.entries});

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const _EmptyState();
    }
    final toAcquire = entries
        .where((e) => e.category == WishlistCategory.toAcquire)
        .toList();
    final toWatch = entries
        .where((e) => e.category == WishlistCategory.toWatch)
        .toList();
    final watched = entries
        .where((e) => e.category == WishlistCategory.watched)
        .toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (toAcquire.isNotEmpty)
          _Section(
            label: 'À télécharger',
            entries: toAcquire,
            keyPrefix: 'acquire',
          ),
        if (toWatch.isNotEmpty)
          _Section(label: 'À visionner', entries: toWatch, keyPrefix: 'watch'),
        if (watched.isNotEmpty)
          _Section(label: 'Déjà vu', entries: watched, keyPrefix: 'watched'),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  final String label;
  final List<WishlistEntryDto> entries;
  final String keyPrefix;

  const _Section({
    required this.label,
    required this.entries,
    required this.keyPrefix,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
          child: Row(
            children: [
              Text(label, style: theme.textTheme.titleMedium),
              const SizedBox(width: 8),
              Text(
                '(${entries.length})',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.hintColor,
                ),
              ),
            ],
          ),
        ),
        for (final e in entries)
          WishlistCard(key: ValueKey('$keyPrefix-${e.watcharrId}'), entry: e),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(32),
      children: [
        const SizedBox(height: 80),
        Icon(
          Icons.bookmark_border,
          size: 56,
          color: Theme.of(context).hintColor,
        ),
        const SizedBox(height: 16),
        Text(
          "Ta liste d'envies est vide",
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Text(
          "Tape sur « Ajouter » en bas à droite pour rechercher un "
          "film ou une série et l'ajouter à ta liste.",
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: Theme.of(context).hintColor),
        ),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  final Object error;
  final WidgetRef ref;

  const _ErrorView({required this.error, required this.ref});

  @override
  Widget build(BuildContext context) {
    if (error is WishlistNotConfiguredException) {
      return _NotConfiguredState();
    }
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 80),
        Icon(Icons.error_outline, size: 56, color: theme.colorScheme.error),
        const SizedBox(height: 16),
        Text(
          'Impossible de charger la liste',
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Text(
          '$error',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
        ),
        const SizedBox(height: 16),
        Center(
          child: FilledButton.tonalIcon(
            onPressed: () =>
                ref.read(wishlistControllerProvider.notifier).refresh(),
            icon: const Icon(Icons.refresh),
            label: const Text('Réessayer'),
          ),
        ),
      ],
    );
  }
}

class _NotConfiguredState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 80),
        Icon(Icons.link_off, size: 56, color: theme.hintColor),
        const SizedBox(height: 16),
        Text(
          'Liste d\'envies non activée',
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Text(
          "Cette fonctionnalité nécessite un compte Watcharr associé à "
          "ton numéro. Demande à l'admin de l'activer.",
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor),
        ),
      ],
    );
  }
}

class _Centered extends StatelessWidget {
  final Widget child;

  const _Centered({required this.child});

  @override
  Widget build(BuildContext context) {
    return ListView(
      // Use ListView so the RefreshIndicator stays usable even on
      // loading / error / empty states.
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 200),
        Center(child: child),
      ],
    );
  }
}
