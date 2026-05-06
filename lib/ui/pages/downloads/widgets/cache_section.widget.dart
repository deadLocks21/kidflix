import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kidflix/core/application/usecases/list_downloads.usecase.dart';
import 'package:kidflix/core/domain/model/download_entry.dart';
import 'package:kidflix/infrastructure/providers/cache_cleanup_preferences.provider.dart';
import 'package:kidflix/infrastructure/providers/download.repository_provider.dart';
import 'package:kidflix/infrastructure/providers/download_management.usecases_provider.dart';
import 'package:kidflix/ui/pages/downloads/widgets/download_entry_tile.widget.dart';
import 'package:kidflix/ui/pages/downloads/widgets/storage_summary_header.widget.dart';

/// Collapsable Cache section. Header summarizes count + size; expanded
/// body exposes the auto-clean toggle, the per-item tiles, and the
/// "Vider le cache" bottom button.
class CacheSection extends ConsumerStatefulWidget {
  final AsyncValue<DownloadInventory> asyncInventory;
  final WidgetRef ref;

  const CacheSection({
    super.key,
    required this.asyncInventory,
    required this.ref,
  });

  @override
  ConsumerState<CacheSection> createState() => _CacheSectionState();
}

class _CacheSectionState extends ConsumerState<CacheSection> {
  bool _expanded = false;
  bool _autoDelete = true;
  bool _autoDeleteLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadAutoDelete();
  }

  Future<void> _loadAutoDelete() async {
    final prefs = ref.read(cacheCleanupPreferencesProvider);
    final enabled = await prefs.isAutoDeleteEnabled();
    if (!mounted) return;
    setState(() {
      _autoDelete = enabled;
      _autoDeleteLoaded = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cacheItems = widget.asyncInventory.maybeWhen(
      data: (inv) => inv.cache,
      orElse: () => const <DownloadEntry>[],
    );
    var totalCacheBytes = 0;
    for (final e in cacheItems) {
      totalCacheBytes += e.bytesOnDisk;
    }

    return Card(
      child: ExpansionTile(
        initiallyExpanded: _expanded,
        onExpansionChanged: (e) => setState(() => _expanded = e),
        title: Text('Cache', style: theme.textTheme.titleLarge),
        subtitle: Text(
          '${cacheItems.length} item${cacheItems.length > 1 ? "s" : ""} · ${formatBytes(totalCacheBytes)}',
        ),
        children: [
          if (_autoDeleteLoaded)
            SwitchListTile(
              title: const Text('Auto-suppression après 30 jours'),
              subtitle: const Text(
                'Les vidéos en cache non vues depuis 30 jours sont supprimées au lancement.',
              ),
              value: _autoDelete,
              onChanged: (v) async {
                setState(() => _autoDelete = v);
                await ref
                    .read(cacheCleanupPreferencesProvider)
                    .setAutoDeleteEnabled(v);
              },
            ),
          if (cacheItems.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: Text('Cache vide.')),
            )
          else
            ...cacheItems.map(
              (entry) => DownloadEntryTile(
                key: ValueKey('${entry.mediaKind}/${entry.mediaId}/cache'),
                entry: entry,
                isInDownloadsSection: false,
              ),
            ),
          if (cacheItems.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => _confirmAndPurgeCache(
                    context,
                    cacheItems.length,
                    totalCacheBytes,
                  ),
                  icon: const Icon(Icons.delete_sweep_outlined),
                  label: const Text('Vider le cache'),
                  style: TextButton.styleFrom(
                    foregroundColor: theme.colorScheme.error,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _confirmAndPurgeCache(
    BuildContext context,
    int count,
    int bytes,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: const Text('Vider le cache ?'),
        content: Text(
          '$count item${count > 1 ? "s" : ""} (${formatBytes(bytes)}) seront supprimés. '
          'Vos vidéos téléchargées (épinglées) ne sont pas concernées.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dCtx).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dCtx).pop(true),
            child: const Text('Vider'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final repo = ref.read(downloadRepositoryProvider);
    final inv = await ref.read(listDownloadsUseCaseProvider).execute();
    for (final entry in inv.cache) {
      try {
        if (entry.isEpisode) {
          await repo.deleteEpisode(entry.mediaId);
        } else {
          await repo.deleteMovie(entry.mediaId);
        }
      } catch (_) {
        // best-effort
      }
    }
    ref.invalidate(downloadInventoryProvider);
    ref.invalidate(storageSummaryProvider);
  }
}
