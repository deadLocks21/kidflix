import 'package:flutter/material.dart';
import 'package:kidflix/core/application/dtos/catalog_item.dto.dart';
import 'package:kidflix/core/application/dtos/catalog_row.dto.dart';
import 'package:kidflix/core/application/dtos/continue_watching_card.dto.dart';
import 'package:kidflix/core/application/dtos/movie.dto.dart';
import 'package:kidflix/core/application/dtos/series.dto.dart';
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
class CatalogRowWidget extends StatelessWidget {
  final CatalogRowDto row;
  final void Function(MovieDto movie) onMovieTap;
  final void Function(SeriesDto series)? onSeriesTap;

  const CatalogRowWidget({
    super.key,
    required this.row,
    required this.onMovieTap,
    this.onSeriesTap,
  });

  static const double _rowHeight = 300;

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
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: row.items.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, i) => _buildCard(context, row.items[i]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(BuildContext context, CatalogItemDto item) {
    if (item is ContinueWatchingCardDto) {
      return _buildLeaf(
        item.inner,
        progress: item.progress,
        onLongPress: () =>
            showDismissContinueWatchingSheet(context, card: item),
      );
    }
    return _buildLeaf(item);
  }

  Widget _buildLeaf(
    CatalogItemDto item, {
    double? progress,
    VoidCallback? onLongPress,
  }) {
    if (item is MovieDto) {
      return MovieCard(
        movie: item,
        onTap: () => onMovieTap(item),
        progress: progress,
        onLongPress: onLongPress,
      );
    }
    if (item is SeriesDto) {
      return SeriesCard(
        series: item,
        onTap: onSeriesTap == null ? null : () => onSeriesTap!(item),
        progress: progress,
        onLongPress: onLongPress,
      );
    }
    // Unknown subtype: empty placeholder.
    return const SizedBox.shrink();
  }
}
