import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kidflix/core/application/usecases/list_downloads.usecase.dart';
import 'package:kidflix/core/application/usecases/run_startup_cache_cleanup.usecase.dart';
import 'package:kidflix/infrastructure/providers/download_management.usecases_provider.dart';
import 'package:kidflix/ui/pages/downloads/widgets/cache_section.widget.dart';
import 'package:kidflix/ui/pages/downloads/widgets/download_entry_tile.widget.dart';
import 'package:kidflix/ui/pages/downloads/widgets/storage_summary_header.widget.dart';

/// Parent-facing manager for downloaded videos and cache.
///
/// Three sections, top to bottom:
/// 1. Storage header (app size + free device space + counters).
/// 2. Téléchargements — items the parent explicitly chose to keep
///    (`kind=download`). Per-item actions: Lire / Ne plus garder /
///    Supprimer.
/// 3. Cache (collapsable, default collapsed) — items downloaded
///    transparently by the player. Includes the auto-clean toggle.
class DownloadsPage extends ConsumerWidget {
  const DownloadsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inventoryAsync = ref.watch(downloadInventoryProvider);
    final summaryAsync = ref.watch(storageSummaryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Téléchargements')),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(downloadInventoryProvider);
            ref.invalidate(storageSummaryProvider);
            await ref.read(downloadInventoryProvider.future);
          },
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              StorageSummaryHeader(asyncSummary: summaryAsync),
              const SizedBox(height: 24),
              _DownloadsSection(asyncInventory: inventoryAsync, ref: ref),
              const SizedBox(height: 24),
              CacheSection(asyncInventory: inventoryAsync, ref: ref),
              const SizedBox(height: 32),
              _ClearAllSection(asyncInventory: inventoryAsync),
              const SizedBox(height: 16),
              _CleanupRetentionFooter(),
            ],
          ),
        ),
      ),
    );
  }
}

class _DownloadsSection extends StatelessWidget {
  final AsyncValue<DownloadInventory> asyncInventory;
  final WidgetRef ref;

  const _DownloadsSection({required this.asyncInventory, required this.ref});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Téléchargements', style: theme.textTheme.titleLarge),
        const SizedBox(height: 8),
        asyncInventory.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => _ErrorBox(message: 'Erreur: $e'),
          data: (inv) {
            if (inv.downloads.isEmpty) {
              return const _EmptyPlaceholder('Rien de téléchargé.');
            }
            return Column(
              children: [
                for (final entry in inv.downloads)
                  DownloadEntryTile(
                    key: ValueKey(
                      '${entry.mediaKind}/${entry.mediaId}/download',
                    ),
                    entry: entry,
                    isInDownloadsSection: true,
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _EmptyPlaceholder extends StatelessWidget {
  final String text;
  const _EmptyPlaceholder(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Center(
        child: Text(
          text,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: Theme.of(context).hintColor),
        ),
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  final String message;
  const _ErrorBox({required this.message});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          message,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onErrorContainer,
          ),
        ),
      ),
    );
  }
}

class _CleanupRetentionFooter extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'Le cache est nettoyé après ${cacheRetention.inDays} jours sans visionnage.',
        style: Theme.of(context).textTheme.bodySmall,
        textAlign: TextAlign.center,
      ),
    );
  }
}

/// Bottom danger zone: wipes every download **and** the whole cache (both
/// kinds) plus the manifest, via [ClearAllDownloadsUseCase]. Distinct from
/// the cache section's "Vider le cache", which spares pinned downloads.
/// Renders nothing when storage is already empty.
class _ClearAllSection extends ConsumerStatefulWidget {
  final AsyncValue<DownloadInventory> asyncInventory;

  const _ClearAllSection({required this.asyncInventory});

  @override
  ConsumerState<_ClearAllSection> createState() => _ClearAllSectionState();
}

class _ClearAllSectionState extends ConsumerState<_ClearAllSection> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final inv = widget.asyncInventory.maybeWhen(
      data: (i) => i,
      orElse: () => null,
    );
    if (inv == null) return const SizedBox.shrink();

    final items = [...inv.downloads, ...inv.cache];
    if (items.isEmpty) return const SizedBox.shrink();

    var totalBytes = 0;
    for (final e in items) {
      totalBytes += e.bytesOnDisk;
    }

    return Center(
      child: TextButton.icon(
        onPressed: _busy
            ? null
            : () => _confirmAndClearAll(context, items.length, totalBytes),
        icon: _busy
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.delete_forever_outlined),
        label: const Text('Tout effacer (cache + téléchargements)'),
        style: TextButton.styleFrom(foregroundColor: theme.colorScheme.error),
      ),
    );
  }

  Future<void> _confirmAndClearAll(
    BuildContext context,
    int count,
    int bytes,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: const Text('Tout effacer ?'),
        content: Text(
          '$count vidéo${count > 1 ? "s" : ""} (${formatBytes(bytes)}) seront '
          'définitivement supprimées : tous les téléchargements ET le cache. '
          'Cette action est irréversible.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dCtx).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dCtx).pop(true),
            child: const Text('Tout effacer'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busy = true);
    try {
      await ref.read(clearAllDownloadsUseCaseProvider).execute();
      ref.invalidate(downloadInventoryProvider);
      ref.invalidate(storageSummaryProvider);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
