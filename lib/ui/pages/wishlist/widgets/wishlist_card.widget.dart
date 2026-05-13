import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kidflix/core/application/dtos/wishlist_entry.dto.dart';
import 'package:kidflix/core/domain/model/wishlist_entry.dart';
import 'package:kidflix/ui/pages/wishlist/widgets/wishlist_entry_actions_sheet.widget.dart';
import 'package:kidflix/ui/router/app_router.dart';

/// One row of the wishlist list view.
///
/// Layout (horizontal):
///
/// - 60×90 poster (or a placeholder when [WishlistEntryDto.posterUrl]
///   is null), with a small "✓" overlay when [WatchedStatus.finished].
/// - Title + year, plus a status / availability badge.
/// - Right-most: a "play" affordance when the entry is available **and**
///   is a movie (series have no direct player route — see doc on
///   [WishlistEntryDto.showsPlayAction]).
///
/// Interactions:
///
/// - Tap on an available movie → push `/player/:movieId`.
/// - Tap on a series or unavailable item → no-op (the badge already
///   communicates the state).
/// - Long press → bottom sheet with "Marquer comme vu" / "Retirer".
class WishlistCard extends StatelessWidget {
  final WishlistEntryDto entry;

  const WishlistCard({super.key, required this.entry});

  @override
  Widget build(BuildContext context) {
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
                    if (entry.year != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        '${entry.year}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.hintColor,
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    _StatusBadge(entry: entry),
                  ],
                ),
              ),
              if (canPlay)
                IconButton(
                  icon: const Icon(Icons.play_arrow),
                  tooltip: 'Lire',
                  onPressed: () => _openPlayer(context),
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
    final iconColor = Theme.of(context).hintColor;
    return Container(
      color: color,
      child: Center(
        child: Icon(
          kind == WishlistItemKind.movie ? Icons.movie : Icons.tv,
          color: iconColor,
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final WishlistEntryDto entry;

  const _StatusBadge({required this.entry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final (label, fg, bg, icon) = _resolve(scheme);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 4),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(color: fg),
          ),
        ],
      ),
    );
  }

  /// Selects the badge content based on availability first, then on the
  /// Watcharr status. Available items get a primary-color badge to
  /// stand out ; unavailable items get a muted "à voir" tone.
  (String, Color, Color, IconData) _resolve(ColorScheme scheme) {
    if (entry.isAvailable) {
      return (
        'Disponible',
        scheme.onPrimaryContainer,
        scheme.primaryContainer,
        Icons.check_circle_outline,
      );
    }
    switch (entry.status) {
      case WatchedStatus.planned:
        return (
          'À voir',
          scheme.onSecondaryContainer,
          scheme.secondaryContainer,
          Icons.bookmark_border,
        );
      case WatchedStatus.watching:
        return (
          'En cours',
          scheme.onTertiaryContainer,
          scheme.tertiaryContainer,
          Icons.play_circle_outline,
        );
      case WatchedStatus.hold:
        return (
          'En pause',
          scheme.onSurfaceVariant,
          scheme.surfaceContainerHighest,
          Icons.pause_circle_outline,
        );
      case WatchedStatus.finished:
        return (
          'Déjà vu',
          scheme.onSurfaceVariant,
          scheme.surfaceContainerHighest,
          Icons.check_circle_outline,
        );
      case WatchedStatus.dropped:
        return (
          'Abandonné',
          scheme.onErrorContainer,
          scheme.errorContainer,
          Icons.cancel_outlined,
        );
    }
  }
}
