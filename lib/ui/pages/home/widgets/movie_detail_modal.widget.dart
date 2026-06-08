import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kidflix/core/application/dtos/movie.dto.dart';
import 'package:kidflix/core/domain/model/cached_cast_member.dart';
import 'package:kidflix/infrastructure/providers/download.repository_provider.dart';
import 'package:kidflix/shared/duration_format.dart';
import 'package:kidflix/ui/pages/home/widgets/download_intent_button.widget.dart';
import 'package:kidflix/ui/pages/home/widgets/favorite_button.widget.dart';
import 'package:kidflix/ui/pages/home/widgets/seen_button.widget.dart';
import 'package:kidflix/ui/pages/home/widgets/trailer_header.widget.dart';

/// Width threshold to choose between dialog and bottom-sheet presentation.
const double _adaptiveBreakpointDp = 600;

/// Opens the movie detail modal for [movie], choosing adaptive presentation:
/// - width `< 600 dp` → full-height [ModalBottomSheet]
/// - width `>= 600 dp` → centered [Dialog] capped at 720 dp wide
Future<void> showMovieDetailModal(
  BuildContext context,
  MovieDetailDto movie,
) async {
  final width = MediaQuery.sizeOf(context).width;
  if (width < _adaptiveBreakpointDp) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => _SheetContainer(child: MovieDetailContent(movie: movie)),
    );
  }
  return showDialog<void>(
    context: context,
    builder: (_) => Dialog(
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 720),
        child: MovieDetailContent(movie: movie),
      ),
    ),
  );
}

class _SheetContainer extends StatelessWidget {
  final Widget child;

  const _SheetContainer({required this.child});

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(heightFactor: 0.92, child: child);
  }
}

/// Layout-agnostic content of the movie detail modal. Same in sheet or
/// dialog mode.
class MovieDetailContent extends StatelessWidget {
  final MovieDetailDto movie;

  const MovieDetailContent({super.key, required this.movie});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              TrailerHeader(
                trailerUrl: movie.trailerUrl,
                fallbackImageUrl: movie.backdropUrl,
                logoUrl: movie.logoUrl,
              ),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton.filled(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(movie.title, style: theme.textTheme.headlineSmall),
                if (movie.originalTitle != null &&
                    movie.originalTitle != movie.title) ...[
                  const SizedBox(height: 2),
                  Text(
                    movie.originalTitle!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontStyle: FontStyle.italic,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                if (movie.tagline != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    movie.tagline!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Text(_metaLine(movie), style: theme.textTheme.bodyMedium),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _PlayButton(movie: movie),
                    const SizedBox(width: 8),
                    DownloadIntentButton(
                      mediaId: movie.id,
                      isEpisode: false,
                      title: movie.title,
                      posterUrl: movie.posterUrl,
                      originalTitle: movie.originalTitle,
                      year: movie.year,
                      durationSeconds: movie.duration.inSeconds,
                      ageCategory: movie.ageCategory,
                      synopsis: movie.synopsis,
                      tagline: movie.tagline,
                      backdropUrl: movie.backdropUrl,
                      logoUrl: movie.logoUrl,
                      genres: movie.genres,
                      director: movie.director,
                      topCast: [
                        for (final c in movie.topCast)
                          CachedCastMember(
                            name: c.name,
                            role: c.role,
                            photoUrl: c.photoUrl,
                          ),
                      ],
                    ),
                    const SizedBox(width: 4),
                    FavoriteButton(target: MovieFavoriteTarget(movie.id)),
                    SeenButton(movieId: movie.id),
                  ],
                ),
                const SizedBox(height: 24),
                Text(movie.synopsis, style: theme.textTheme.bodyMedium),
                if (movie.genres.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  _Section(
                    title: 'Genres',
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        for (final g in movie.genres) Chip(label: Text(g)),
                      ],
                    ),
                  ),
                ],
                if (movie.director.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  _Section(
                    title: movie.director.length > 1
                        ? 'Réalisation'
                        : 'Réalisateur',
                    child: Text(
                      movie.director.join(', '),
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ],
                if (movie.topCast.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  _Section(
                    title: 'Casting',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final c in movie.topCast)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              c.role == null ? c.name : '${c.name} — ${c.role}',
                              style: theme.textTheme.bodyMedium,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _metaLine(MovieDetailDto movie) {
    final parts = <String>[];
    if (movie.year != null) parts.add(movie.year.toString());
    parts.add(formatDurationHuman(movie.duration));
    if (movie.genres.isNotEmpty) parts.add(movie.genres.first);
    return parts.join(' · ');
  }
}

class _PlayButton extends ConsumerWidget {
  final MovieDetailDto movie;

  const _PlayButton({required this.movie});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FilledButton.icon(
      icon: const Icon(Icons.play_arrow),
      label: const Text('Lire'),
      onPressed: () {
        // Pre-cache the full display snapshot so the manager can resolve
        // this movie even if the parent profile cannot see it via
        // /catalog, and so the offline home can render rows + the detail
        // modal from disk only. Best-effort, fire-and-forget.
        unawaited(
          ref
              .read(downloadRepositoryProvider)
              .cacheMediaMetadata(
                mediaId: movie.id,
                isEpisode: false,
                title: movie.title,
                posterUrl: movie.posterUrl,
                originalTitle: movie.originalTitle,
                year: movie.year,
                durationSeconds: movie.duration.inSeconds,
                ageCategory: movie.ageCategory,
                synopsis: movie.synopsis,
                tagline: movie.tagline,
                backdropUrl: movie.backdropUrl,
                logoUrl: movie.logoUrl,
                genres: movie.genres,
                director: movie.director,
                topCast: [
                  for (final c in movie.topCast)
                    CachedCastMember(
                      name: c.name,
                      role: c.role,
                      photoUrl: c.photoUrl,
                    ),
                ],
              ),
        );
        Navigator.of(context).pop();
        context.go('/player/${movie.id}');
      },
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;

  const _Section({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}
