import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kidflix/core/application/session_state.dart';
import 'package:kidflix/core/domain/model/download_entry.dart';
import 'package:kidflix/infrastructure/providers/download.repository_provider.dart';
import 'package:kidflix/infrastructure/providers/download_management.usecases_provider.dart';
import 'package:kidflix/infrastructure/providers/session.controller_provider.dart';
import 'package:kidflix/shared/tmdb_image.dart';
import 'package:kidflix/ui/pages/downloads/widgets/storage_summary_header.widget.dart';

/// One row in the manager's downloads or cache section.
///
/// Collapsed: poster + title + subtitle + size. Tap to expand into
/// `[Lire] [Garder/Ne plus garder] [Supprimer]`. Confirmation dialog
/// before any [Supprimer].
class DownloadEntryTile extends ConsumerStatefulWidget {
  final DownloadEntry entry;

  /// `true` when the tile is rendered inside the Downloads section
  /// (`kind=download` items). `false` for the Cache section. Drives
  /// the label of the kind-flip action ("Ne plus garder" vs "Garder").
  final bool isInDownloadsSection;

  const DownloadEntryTile({
    super.key,
    required this.entry,
    required this.isInDownloadsSection,
  });

  @override
  ConsumerState<DownloadEntryTile> createState() => _DownloadEntryTileState();
}

class _DownloadEntryTileState extends ConsumerState<DownloadEntryTile> {
  bool _expanded = false;
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entry = widget.entry;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        children: [
          ListTile(
            leading: SizedBox(
              width: 56,
              height: 56,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: entry.displayPosterUrl != null
                    ? CachedNetworkImage(
                        imageUrl: tmdbResize(entry.displayPosterUrl!, 'w185'),
                        fit: BoxFit.cover,
                        filterQuality: FilterQuality.medium,
                        memCacheWidth:
                            (56 * MediaQuery.devicePixelRatioOf(context))
                                .round(),
                        placeholder: (_, _) => Container(color: Colors.grey[300]),
                        errorWidget: (_, _, _) =>
                            Container(color: Colors.grey[400]),
                      )
                    : Container(color: Colors.grey[300]),
              ),
            ),
            title: Text(
              entry.parentSeriesTitle != null
                  ? '${entry.parentSeriesTitle} — ${entry.displayTitle}'
                  : entry.displayTitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              _subtitleFor(context, entry),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Text(
              formatBytes(entry.bytesOnDisk),
              style: theme.textTheme.bodySmall,
            ),
            onTap: _busy
                ? null
                : () => setState(() => _expanded = !_expanded),
          ),
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: _busy ? null : () => _toggleKind(context),
                    icon: Icon(widget.isInDownloadsSection
                        ? Icons.bookmark_remove_outlined
                        : Icons.bookmark_add_outlined),
                    label: Text(widget.isInDownloadsSection
                        ? 'Ne plus garder'
                        : 'Garder'),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: _busy ? null : () => _delete(context),
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Supprimer'),
                    style: TextButton.styleFrom(
                      foregroundColor: theme.colorScheme.error,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _subtitleFor(BuildContext context, DownloadEntry entry) {
    final triggeredBy = _resolveProfileLabel(entry.triggeredByProfileId);
    final lastPlayed = entry.lastPlayedAt;
    final ago = lastPlayed == null
        ? 'jamais lu'
        : 'vu ${_relativeAge(DateTime.now().difference(lastPlayed))}';
    if (entry.displayTitle == 'Vidéo inconnue') {
      return 'Vidéo absente du catalogue · $ago';
    }
    return '$triggeredBy · $ago';
  }

  String _resolveProfileLabel(String? profileId) {
    if (profileId == null) return 'Téléchargé par un autre appareil';
    final state = ref.read(sessionControllerProvider);
    final profiles = switch (state) {
      Authenticated(:final session) => session.profiles,
      ProfileSelected(:final session) => session.profiles,
      ManagementPinRequired(:final session) => session.profiles,
      ManagingProfiles(:final session) => session.profiles,
      _ => const [],
    };
    final match = profiles.where((p) => p.id == profileId).firstOrNull;
    return match == null
        ? 'Téléchargé par profil supprimé'
        : 'Téléchargé par ${match.name}';
  }

  String _relativeAge(Duration d) {
    if (d.inMinutes < 60) return 'il y a moins d\'une heure';
    if (d.inHours < 24) return 'il y a ${d.inHours} h';
    if (d.inDays == 1) return 'hier';
    if (d.inDays < 30) return 'il y a ${d.inDays} j';
    final months = (d.inDays / 30).floor();
    return 'il y a $months mois';
  }

  Future<void> _toggleKind(BuildContext context) async {
    setState(() => _busy = true);
    try {
      if (widget.isInDownloadsSection) {
        await ref.read(markAsCacheUseCaseProvider).execute(
              mediaId: widget.entry.mediaId,
              isEpisode: widget.entry.isEpisode,
            );
      } else {
        await ref.read(markAsDownloadUseCaseProvider).execute(
              mediaId: widget.entry.mediaId,
              isEpisode: widget.entry.isEpisode,
            );
      }
      ref.invalidate(downloadInventoryProvider);
      ref.invalidate(storageSummaryProvider);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete(BuildContext context) async {
    final entry = widget.entry;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: Text('Supprimer ${entry.displayTitle} ?'),
        content: Text(
          '${formatBytes(entry.bytesOnDisk)} seront libérés. '
          'Cette action ne peut pas être annulée.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dCtx).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dCtx).pop(true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busy = true);
    try {
      final repo = ref.read(downloadRepositoryProvider);
      if (entry.isEpisode) {
        await repo.deleteEpisode(entry.mediaId);
      } else {
        await repo.deleteMovie(entry.mediaId);
      }
      ref.invalidate(downloadInventoryProvider);
      ref.invalidate(storageSummaryProvider);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
