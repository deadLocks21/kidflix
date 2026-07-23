import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kidflix/core/application/dtos/movie.dto.dart';
import 'package:kidflix/infrastructure/providers/remote_catalog.provider.dart';
import 'package:kidflix/shared/duration_format.dart';
import 'package:kidflix/ui/pages/remote/cast_playback.dart';
import 'package:kidflix/ui/theme/kidflix_palette.dart';

/// Detail sheet for a movie in the *host's* catalogue.
///
/// Distinct from the local `MovieDetailModal`: the movie belongs to a
/// profile the local account cannot read, so its detail is fetched from
/// the host over the socket, and the only action is to cast — there is
/// no local download or "Lire ici".
Future<void> showRemoteMovieDetailModal(
  BuildContext context, {
  required String movieId,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: KidflixPalette.grey900,
    showDragHandle: true,
    builder: (_) => _RemoteMovieDetail(movieId: movieId),
  );
}

class _RemoteMovieDetail extends ConsumerWidget {
  final String movieId;

  const _RemoteMovieDetail({required this.movieId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(remoteMovieDetailProvider(movieId));
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, controller) => detail.when(
        loading: () => const SizedBox(
          height: 240,
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (_, _) => _ErrorState(
          onRetry: () => ref.invalidate(remoteMovieDetailProvider(movieId)),
        ),
        data: (movie) => _Content(movie: movie, scrollController: controller),
      ),
    );
  }
}

class _Content extends ConsumerWidget {
  final MovieDetailDto movie;
  final ScrollController scrollController;

  const _Content({required this.movie, required this.scrollController});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deviceName = castTargetName(ref);
    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      children: [
        if (movie.backdropUrl != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: CachedNetworkImage(
                imageUrl: movie.backdropUrl!,
                fit: BoxFit.cover,
                errorWidget: (_, _, _) =>
                    Container(color: KidflixPalette.grey800),
              ),
            ),
          ),
        const SizedBox(height: 16),
        Text(
          movie.title,
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          _metaLine(movie),
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: KidflixPalette.grey100),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          icon: const Icon(Icons.cast_connected),
          label: Text(
            deviceName == null ? 'Lire' : 'Lire sur $deviceName',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          onPressed: () async {
            final cast = await castIfRemoting(
              context,
              ref,
              mediaId: movie.id,
            );
            if (!context.mounted) return;
            // Casting always applies here (the sheet only exists while
            // driving a host), so close either way.
            Navigator.of(context).pop();
            if (!cast) {
              // Connection dropped between opening the sheet and tapping.
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Appareil déconnecté.')),
              );
            }
          },
        ),
        const SizedBox(height: 20),
        Text(movie.synopsis, style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }

  static String _metaLine(MovieDetailDto movie) {
    final parts = <String>[
      if (movie.year != null) '${movie.year}',
      formatDurationHuman(movie.duration),
      if (movie.genres.isNotEmpty) movie.genres.first,
    ];
    return parts.join(' · ');
  }
}

class _ErrorState extends StatelessWidget {
  final VoidCallback onRetry;

  const _ErrorState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: KidflixPalette.red100),
          const SizedBox(height: 12),
          const Text(
            'Impossible de récupérer les détails depuis l’appareil.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          OutlinedButton(onPressed: onRetry, child: const Text('Réessayer')),
        ],
      ),
    );
  }
}
