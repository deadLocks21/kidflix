import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:kidflix/core/application/dtos/series.dto.dart';

/// Compact series tile rendered inside a horizontal [ListView].
///
/// Same dimensions as `MovieCard` (160dp wide, 240dp poster height) so
/// both tile types align in mixed rows. The caption replaces the
/// duration with a saisons / épisodes summary.
class SeriesCard extends StatelessWidget {
  static const double width = 160;
  static const double posterHeight = 240;

  final SeriesDto series;
  final VoidCallback? onTap;

  const SeriesCard({super.key, required this.series, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: width,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: width,
                  height: posterHeight,
                  child: _Poster(posterUrl: series.posterUrl),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                series.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: 2),
              Text(
                _caption(series),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _caption(SeriesDto series) {
    final seasons = series.seasonsCount;
    final saisonsLabel = seasons <= 1 ? '$seasons saison' : '$seasons saisons';
    if (series.year == null) return saisonsLabel;
    return '${series.year} · $saisonsLabel';
  }
}

class _Poster extends StatelessWidget {
  final String? posterUrl;

  const _Poster({required this.posterUrl});

  @override
  Widget build(BuildContext context) {
    final fallback = _PosterFallback();
    final url = posterUrl;
    if (url == null || url.isEmpty) return fallback;
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
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
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      color: theme.colorScheme.surfaceContainerHigh,
      alignment: Alignment.center,
      child: Icon(
        Icons.tv_outlined,
        size: 48,
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}
