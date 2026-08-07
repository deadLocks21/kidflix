import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:kidflix/core/application/dtos/series.dto.dart';
import 'package:kidflix/shared/tmdb_image.dart';
import 'package:kidflix/ui/focus/kidflix_focus_ring.widget.dart';
import 'package:kidflix/ui/focus/kidflix_focusable.widget.dart';
import 'package:kidflix/ui/pages/home/widgets/resume_progress_bar.widget.dart';

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

  /// Resume progress in `[0, 1]`. When non-null and `> 0`, a thin
  /// progress strip is overlaid at the bottom of the poster.
  final double? progress;

  /// Optional long-press handler. Wired by the Continue Watching row to
  /// open the "Retirer" action sheet ; other rows leave it null.
  final VoidCallback? onLongPress;

  /// Supplied by the catalog focus coordinator, which owns one node per
  /// (row, column) so it can move focus by index rather than by geometry.
  final FocusNode? focusNode;

  final bool autofocus;

  const SeriesCard({
    super.key,
    required this.series,
    this.onTap,
    this.progress,
    this.onLongPress,
    this.focusNode,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: width,
      child: KidflixFocusable(
        onTap: onTap,
        onLongPress: onLongPress,
        focusNode: focusNode,
        autofocus: autofocus,
        borderRadius: BorderRadius.circular(8),
        // The ring goes around the poster only, placed below — see the
        // [KidflixFocusRing] on the next lines.
        ring: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            KidflixFocusRing(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: width,
                  height: posterHeight,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: _Poster(posterUrl: series.posterUrl),
                      ),
                      if (progress != null && progress! > 0)
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: ResumeProgressBar(progress: progress!),
                        ),
                    ],
                  ),
                ),
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
            // Built below the focusable so it can read its state: the
            // caption steps up from grey to full white on the selected
            // card, which is what makes the whole tile come forward
            // rather than just its outline.
            Builder(
              builder: (context) => AnimatedDefaultTextStyle(
                duration: KidflixFocusable.duration,
                curve: KidflixFocusable.curve,
                style:
                    theme.textTheme.bodySmall?.copyWith(
                      color: KidflixFocusable.isFocused(context)
                          ? theme.colorScheme.onSurface
                          : theme.colorScheme.onSurfaceVariant,
                    ) ??
                    const TextStyle(),
                child: Text(
                  _caption(series),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
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
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return CachedNetworkImage(
      imageUrl: tmdbResize(url, 'w342'),
      fit: BoxFit.cover,
      filterQuality: FilterQuality.medium,
      memCacheWidth: (SeriesCard.width * dpr).round(),
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
