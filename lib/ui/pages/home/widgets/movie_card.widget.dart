import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:kidflix/core/application/dtos/movie.dto.dart';
import 'package:kidflix/shared/duration_format.dart';
import 'package:kidflix/ui/pages/home/widgets/resume_progress_bar.widget.dart';

/// Compact movie tile rendered inside a horizontal [ListView].
///
/// Fixed width of 160dp with a 2:3 poster (240dp tall). Title and caption
/// line sit below the poster. Tapping the card triggers [onTap] — the
/// homepage wires it to open the detail modal.
class MovieCard extends StatelessWidget {
  static const double width = 160;
  static const double posterHeight = 240;

  final MovieDto movie;
  final VoidCallback onTap;

  /// Resume progress in `[0, 1]`. When non-null and `> 0`, a thin
  /// progress strip is overlaid at the bottom of the poster.
  final double? progress;

  const MovieCard({
    super.key,
    required this.movie,
    required this.onTap,
    this.progress,
  });

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
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: _Poster(posterUrl: movie.posterUrl),
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
              const SizedBox(height: 8),
              Text(
                movie.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: 2),
              Text(
                _caption(movie),
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

  static String _caption(MovieDto movie) {
    final duration = formatDurationHuman(movie.duration);
    if (movie.year == null) return duration;
    return '${movie.year} · $duration';
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
        Icons.movie_outlined,
        size: 48,
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}
