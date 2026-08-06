import 'package:flutter/material.dart';
import 'package:kidflix/core/application/dtos/catalog_item.dto.dart';
import 'package:kidflix/core/application/dtos/catalog_row.dto.dart';
import 'package:kidflix/core/application/dtos/continue_watching_card.dto.dart';
import 'package:kidflix/core/application/dtos/movie.dto.dart';
import 'package:kidflix/core/application/dtos/series.dto.dart';
import 'package:kidflix/ui/focus/catalog_focus.dart';
import 'package:kidflix/ui/pages/home/widgets/dismiss_continue_watching_sheet.widget.dart';
import 'package:kidflix/ui/pages/home/widgets/movie_card.widget.dart';
import 'package:kidflix/ui/pages/home/widgets/series_card.widget.dart';

/// One horizontal row of catalog items (mixed movie / series), prefixed
/// with a row label.
///
/// Switches on the runtime DTO type to render the right card variant.
/// Series tap currently delegates to a series-specific callback ; movie
/// tap keeps the existing onMovieTap signature for backward compat with
/// the homepage's controller.
///
/// Long-press on a [ContinueWatchingCardDto] opens the "Retirer de
/// Continuer à regarder" bottom sheet. Cards from other rows ignore
/// long-press.
///
/// Registers itself with the ambient [CatalogFocusScope] under [index] so
/// keyboard traversal can address its cards by column.
class CatalogRowWidget extends StatelessWidget {
  final int index;
  final CatalogRowDto row;
  final void Function(MovieDto movie) onMovieTap;
  final void Function(SeriesDto series)? onSeriesTap;

  const CatalogRowWidget({
    super.key,
    required this.index,
    required this.row,
    required this.onMovieTap,
    this.onSeriesTap,
  });

  /// Tall enough to hold a card *and* the room its focus zoom grows into —
  /// the row's [ListView] clips, so without the slack the top of a focused
  /// poster would be shaved off.
  static const double _rowHeight = 320;
  static const double _separator = 12;
  static const double _horizontalInset = 16;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(row.label, style: theme.textTheme.titleLarge),
          ),
          SizedBox(
            height: _rowHeight,
            child: CatalogFocusRow(
              index: index,
              itemCount: row.items.length,
              stride: MovieCard.width + _separator,
              leadingInset: _horizontalInset,
              itemExtent: MovieCard.width,
              builder: (context, controller) => ListView.separated(
                controller: controller,
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: _horizontalInset,
                ),
                itemCount: row.items.length,
                separatorBuilder: (_, _) => const SizedBox(width: _separator),
                itemBuilder: (context, i) => CatalogFocusItem(
                  row: index,
                  column: i,
                  // Centred so the zoom grows symmetrically into the
                  // slack baked into [_rowHeight].
                  builder: (context, node, autofocus) => Center(
                    child: _buildCard(
                      context,
                      row.items[i],
                      node: node,
                      autofocus: autofocus,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(
    BuildContext context,
    CatalogItemDto item, {
    required FocusNode node,
    required bool autofocus,
  }) {
    if (item is ContinueWatchingCardDto) {
      return _buildLeaf(
        item.inner,
        node: node,
        autofocus: autofocus,
        progress: item.progress,
        onLongPress: () =>
            showDismissContinueWatchingSheet(context, card: item),
      );
    }
    return _buildLeaf(item, node: node, autofocus: autofocus);
  }

  Widget _buildLeaf(
    CatalogItemDto item, {
    required FocusNode node,
    required bool autofocus,
    double? progress,
    VoidCallback? onLongPress,
  }) {
    if (item is MovieDto) {
      return MovieCard(
        movie: item,
        onTap: () => onMovieTap(item),
        progress: progress,
        onLongPress: onLongPress,
        focusNode: node,
        autofocus: autofocus,
      );
    }
    if (item is SeriesDto) {
      return SeriesCard(
        series: item,
        onTap: onSeriesTap == null ? null : () => onSeriesTap!(item),
        progress: progress,
        onLongPress: onLongPress,
        focusNode: node,
        autofocus: autofocus,
      );
    }
    // Unknown subtype: empty placeholder.
    return const SizedBox.shrink();
  }
}
