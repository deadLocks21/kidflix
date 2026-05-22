import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:kidflix/core/application/dtos/catalog_item.dto.dart';
import 'package:kidflix/core/application/dtos/movie.dto.dart';
import 'package:kidflix/core/application/dtos/series.dto.dart';
import 'package:kidflix/shared/duration_format.dart';
import 'package:kidflix/shared/tmdb_image.dart';

/// Single-line result row rendered inside the search results list.
///
/// Renders both [MovieDto] and [SeriesDto] entries — the caption switches
/// on the runtime type ([MovieDto] shows the duration ; [SeriesDto] shows
/// the saisons / épisodes count).
class SearchResultTile extends StatelessWidget {
  static const double posterWidth = 60;
  static const double posterHeight = 90;

  final CatalogItemDto item;
  final VoidCallback onTap;

  const SearchResultTile({super.key, required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: SizedBox(
                width: SearchResultTile.posterWidth,
                height: SearchResultTile.posterHeight,
                child: _Poster(posterUrl: item.posterUrl, item: item),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _caption(item),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }

  static String _caption(CatalogItemDto item) {
    if (item is MovieDto) {
      final duration = formatDurationHuman(item.duration);
      return item.year == null ? duration : '${item.year} · $duration';
    }
    if (item is SeriesDto) {
      final seasons = item.seasonsCount;
      final saisonsLabel = seasons <= 1
          ? '$seasons saison'
          : '$seasons saisons';
      return item.year == null ? saisonsLabel : '${item.year} · $saisonsLabel';
    }
    return '';
  }
}

class _Poster extends StatelessWidget {
  final String? posterUrl;
  final CatalogItemDto item;

  const _Poster({required this.posterUrl, required this.item});

  @override
  Widget build(BuildContext context) {
    final fallback = _PosterFallback(item: item);
    final url = posterUrl;
    if (url == null || url.isEmpty) return fallback;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return CachedNetworkImage(
      imageUrl: tmdbResize(url, 'w185'),
      fit: BoxFit.cover,
      filterQuality: FilterQuality.medium,
      memCacheWidth: (SearchResultTile.posterWidth * dpr).round(),
      placeholder: (_, _) => const _PosterPlaceholder(),
      errorWidget: (_, _, _) => fallback,
    );
  }
}

class _PosterPlaceholder extends StatelessWidget {
  const _PosterPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(color: Theme.of(context).colorScheme.surfaceContainerHigh);
  }
}

class _PosterFallback extends StatelessWidget {
  final CatalogItemDto item;

  const _PosterFallback({required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      color: theme.colorScheme.surfaceContainerHigh,
      alignment: Alignment.center,
      child: Icon(
        item is SeriesDto ? Icons.tv_outlined : Icons.movie_outlined,
        size: 24,
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}
