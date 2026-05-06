import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kidflix/core/application/usecases/get_storage_summary.usecase.dart';

/// Header card on the downloads page : total bytes consumed by the app,
/// device free space, and the two counters.
class StorageSummaryHeader extends StatelessWidget {
  final AsyncValue<StorageSummary> asyncSummary;

  const StorageSummaryHeader({super.key, required this.asyncSummary});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: asyncSummary.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text('Erreur: $e'),
          data: (s) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Stockage', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(
                'Kidflix occupe ${formatBytes(s.appDownloadsBytes)}',
                style: theme.textTheme.bodyLarge,
              ),
              const SizedBox(height: 4),
              Text(
                s.deviceFreeBytes != null
                    ? 'Libre sur l\'appareil : ${formatBytes(s.deviceFreeBytes!)}'
                    : 'Libre sur l\'appareil : indisponible',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              Text(
                '${s.downloadsCount} téléchargement${s.downloadsCount > 1 ? "s" : ""} · ${s.cacheCount} en cache',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.hintColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Human-readable byte formatter. `< 1 KB` → `"X o"`,
/// `< 1 MB` → `"X Ko"`, `< 1 GB` → `"X.Y Mo"`,
/// otherwise `"X.Y Go"`.
String formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes o';
  final kb = bytes / 1024;
  if (kb < 1024) return '${kb.toStringAsFixed(0)} Ko';
  final mb = kb / 1024;
  if (mb < 1024) return '${mb.toStringAsFixed(mb < 10 ? 1 : 0)} Mo';
  final gb = mb / 1024;
  return '${gb.toStringAsFixed(1)} Go';
}
