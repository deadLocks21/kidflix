import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kidflix/core/application/dtos/wishlist_entry.dto.dart';
import 'package:kidflix/core/domain/exceptions/wishlist_not_configured.exception.dart';
import 'package:kidflix/infrastructure/providers/wishlist.controller_provider.dart';
import 'package:kidflix/ui/pages/wishlist/widgets/wishlist_card.widget.dart';

/// Parent-only wishlist page, accessible from the home avatar menu →
/// "Liste d'envies".
///
/// Renders the foyer's "films à voir non encore disponibles" — the
/// filter is applied by [ListWishlistUseCase] (movies, planned, not
/// in the catalog). A single flat list, sorted alphabetically by
/// title. Pull-to-refresh re-hits the proxy.
///
/// Long-press on a row opens the bottom sheet to mark the entry as
/// vu (FINISHED → drops out of the filter) or to retirer (DELETE →
/// drops out for good).
///
/// Edge cases handled inline:
///
/// - `WishlistNotConfiguredException` (503) → dedicated empty state
///   telling the parent to provision a Watcharr account.
/// - Other errors → generic error card with a refresh button.
/// - Empty filter result → friendly placeholder pointing to Watcharr.
class WishlistPage extends ConsumerWidget {
  const WishlistPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncEntries = ref.watch(wishlistControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text("Liste d'envies")),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => ref
              .read(wishlistControllerProvider.notifier)
              .refresh(),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: asyncEntries.when(
                loading: () => const _Centered(
                  child: CircularProgressIndicator(),
                ),
                error: (e, _) => _ErrorView(error: e, ref: ref),
                data: (entries) => _List(entries: entries),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _List extends StatelessWidget {
  final List<WishlistEntryDto> entries;

  const _List({required this.entries});

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const _EmptyState();
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final e in entries)
          WishlistCard(key: ValueKey(e.watcharrId), entry: e),
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
          "Aucune envie à acquérir",
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Text(
          "Ajoute des films ou séries depuis Watcharr — ils "
          "apparaîtront ici tant qu'ils ne sont pas encore dans la "
          "médiathèque.",
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).hintColor,
              ),
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
        Icon(
          Icons.error_outline,
          size: 56,
          color: theme.colorScheme.error,
        ),
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
            onPressed: () => ref
                .read(wishlistControllerProvider.notifier)
                .refresh(),
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
        Icon(
          Icons.link_off,
          size: 56,
          color: theme.hintColor,
        ),
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
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.hintColor,
          ),
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
