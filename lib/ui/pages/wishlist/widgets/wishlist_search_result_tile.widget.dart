import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kidflix/core/application/dtos/wishlist_search_result.dto.dart';
import 'package:kidflix/core/domain/exceptions/wishlist_entry_already_exists.exception.dart';
import 'package:kidflix/core/domain/model/wishlist_entry.dart';
import 'package:kidflix/infrastructure/providers/wishlist.controller_provider.dart';

/// One row of the wishlist search results.
///
/// Mirrors the layout of [WishlistCard] (poster + title + year +
/// hint) and adds a trailing "Ajouter" button. The button is
/// disabled when the item is already in the foyer's wishlist
/// (`alreadyInWishlist`). Items already in the catalog can still be
/// added — the wishlist filter just hides them downstream.
///
/// On press: the controller's [WishlistController.add] is called.
/// Success → SnackBar "Ajouté à la liste". Already-exists error →
/// SnackBar "Déjà dans la liste". Other errors → generic SnackBar.
class WishlistSearchResultTile extends ConsumerStatefulWidget {
  final WishlistSearchResultDto result;

  const WishlistSearchResultTile({super.key, required this.result});

  @override
  ConsumerState<WishlistSearchResultTile> createState() =>
      _WishlistSearchResultTileState();
}

class _WishlistSearchResultTileState
    extends ConsumerState<WishlistSearchResultTile> {
  bool _adding = false;
  bool _added = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final result = widget.result;
    final alreadyMarked = _added || result.alreadyInWishlist;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _Poster(result: result),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    result.title,
                    style: theme.textTheme.titleSmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      _KindChip(kind: result.kind),
                      if (result.year != null) ...[
                        const SizedBox(width: 8),
                        Text(
                          '${result.year}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.hintColor,
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (result.hintLabel != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      result.hintLabel!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.hintColor,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            _AddButton(
              adding: _adding,
              added: alreadyMarked,
              onPressed: alreadyMarked || _adding ? null : _onAdd,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _onAdd() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _adding = true);
    try {
      await ref.read(wishlistControllerProvider.notifier).add(
            tmdbId: widget.result.tmdbId,
            kind: widget.result.kind,
          );
      if (!mounted) return;
      setState(() {
        _adding = false;
        _added = true;
      });
      messenger.showSnackBar(
        SnackBar(content: Text('« ${widget.result.title} » ajouté à la liste')),
      );
    } on WishlistEntryAlreadyExistsException {
      if (!mounted) return;
      setState(() {
        _adding = false;
        _added = true;
      });
      messenger.showSnackBar(
        const SnackBar(content: Text('Déjà dans la liste')),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _adding = false);
      messenger.showSnackBar(
        const SnackBar(content: Text('Impossible d\'ajouter')),
      );
    }
  }
}

class _Poster extends StatelessWidget {
  final WishlistSearchResultDto result;

  const _Poster({required this.result});

  @override
  Widget build(BuildContext context) {
    final url = result.posterUrl;
    final placeholder = _PosterPlaceholder(kind: result.kind);
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

class _AddButton extends StatelessWidget {
  final bool adding;
  final bool added;
  final VoidCallback? onPressed;

  const _AddButton({
    required this.adding,
    required this.added,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    if (adding) {
      return const SizedBox(
        width: 40,
        height: 40,
        child: Padding(
          padding: EdgeInsets.all(8),
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    if (added) {
      return IconButton(
        icon: const Icon(Icons.check_circle),
        color: Theme.of(context).colorScheme.primary,
        onPressed: null,
        tooltip: 'Dans la liste',
      );
    }
    return IconButton(
      icon: const Icon(Icons.add_circle_outline),
      onPressed: onPressed,
      tooltip: 'Ajouter',
    );
  }
}
