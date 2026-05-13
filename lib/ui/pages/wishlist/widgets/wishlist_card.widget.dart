import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kidflix/core/application/dtos/wishlist_entry.dto.dart';
import 'package:kidflix/core/domain/model/wishlist_entry.dart';
import 'package:kidflix/infrastructure/providers/wishlist.controller_provider.dart';
import 'package:kidflix/ui/pages/wishlist/widgets/wishlist_entry_actions_sheet.widget.dart';
import 'package:kidflix/ui/router/app_router.dart';

/// One row of the wishlist list view.
///
/// Layout (horizontal):
///
/// - 60×90 poster (or a kind-aware placeholder when [WishlistEntryDto.posterUrl]
///   is null).
/// - Title + year + kind chip (Film / Série).
/// - Trailing icon buttons :
///   - "Lire" — only when the entry is available **and** is a movie
///     (series have no direct player route).
///   - "Supprimer" — always present, removes the entry from Watcharr
///     via the controller's optimistic `remove`.
///
/// Interactions:
///
/// - Tap on an available movie → push `/player/:movieId`.
/// - Tap on a series or unavailable item → no-op.
/// - Long press → bottom sheet with "Marquer comme vu" / "Retirer"
///   (kept for the secondary "mark as watched" action ; the visible
///   delete button is a redundant-on-purpose shortcut for the most
///   common destructive action).
class WishlistCard extends ConsumerWidget {
  final WishlistEntryDto entry;

  const WishlistCard({super.key, required this.entry});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final canPlay = entry.isAvailable && entry.kind == WishlistItemKind.movie;
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        onTap: canPlay ? () => _openPlayer(context) : null,
        onLongPress: () => showWishlistEntryActionsSheet(
          context,
          entry: entry,
        ),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _Poster(entry: entry),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.title,
                      style: theme.textTheme.titleSmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        _KindChip(kind: entry.kind),
                        if (entry.year != null) ...[
                          const SizedBox(width: 8),
                          Text(
                            '${entry.year}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.hintColor,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              if (canPlay)
                IconButton(
                  icon: const Icon(Icons.play_arrow),
                  tooltip: 'Lire',
                  onPressed: () => _openPlayer(context),
                ),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Supprimer de la liste',
                onPressed: () => _onDelete(context, ref),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openPlayer(BuildContext context) {
    final catalogId = entry.catalogId;
    if (catalogId == null) return;
    context.push(AppRoutes.player.replaceFirst(':movieId', catalogId));
  }

  Future<void> _onDelete(BuildContext context, WidgetRef ref) async {
    // Capture handles before the await — the card unmounts as soon as
    // the optimistic remove runs, so reaching for `context` after is
    // a use-after-dispose hazard.
    final messenger = ScaffoldMessenger.of(context);
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

class _Poster extends StatelessWidget {
  final WishlistEntryDto entry;

  const _Poster({required this.entry});

  @override
  Widget build(BuildContext context) {
    final url = entry.posterUrl;
    final placeholder = _PosterPlaceholder(kind: entry.kind);
    final image = url == null
        ? placeholder
        : CachedNetworkImage(
            imageUrl: url,
            fit: BoxFit.cover,
            placeholder: (_, _) => placeholder,
            errorWidget: (_, _, _) => placeholder,
          );
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(width: 60, height: 90, child: image),
    );
  }
}

class _PosterPlaceholder extends StatelessWidget {
  final WishlistItemKind kind;

  const _PosterPlaceholder({required this.kind});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.surfaceContainerHighest;
    return Container(
      color: color,
      child: Center(
        child: Icon(
          kind == WishlistItemKind.movie ? Icons.movie : Icons.tv,
          color: Theme.of(context).hintColor,
        ),
      ),
    );
  }
}

class _KindChip extends StatelessWidget {
  final WishlistItemKind kind;

  const _KindChip({required this.kind});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = kind == WishlistItemKind.movie ? 'Film' : 'Série';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSecondaryContainer,
        ),
      ),
    );
  }
}
