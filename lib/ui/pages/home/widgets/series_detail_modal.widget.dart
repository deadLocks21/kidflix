import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kidflix/core/application/session_state.dart';
import 'package:kidflix/core/domain/model/media.dart';
import 'package:kidflix/core/domain/model/watch_progress.dart';
import 'package:kidflix/infrastructure/providers/series.repository_provider.dart';
import 'package:kidflix/infrastructure/providers/session.controller_provider.dart';
import 'package:kidflix/infrastructure/providers/watch_progress.repository_provider.dart';
import 'package:kidflix/shared/duration_format.dart';
import 'package:kidflix/ui/pages/home/widgets/series/play_label.dart';

const double _adaptiveBreakpointDp = 600;

/// Opens the series detail modal for [series], choosing adaptive
/// presentation:
///
/// - width `< 600 dp` → full-height [ModalBottomSheet]
/// - width `>= 600 dp` → centered [Dialog] capped at 720 dp wide
///
/// The modal triggers a fetch of the full series tree (with seasons +
/// episodes) on open via `seriesRepositoryProvider.findById` — the
/// [series] argument is the catalog projection (no episodes).
Future<void> showSeriesDetailModal(
  BuildContext context,
  Series series,
) async {
  final width = MediaQuery.sizeOf(context).width;
  if (width < _adaptiveBreakpointDp) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) =>
          _SheetContainer(child: SeriesDetailContent(catalogSeries: series)),
    );
  }
  return showDialog<void>(
    context: context,
    builder: (_) => Dialog(
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 720),
        child: SeriesDetailContent(catalogSeries: series),
      ),
    ),
  );
}

class _SheetContainer extends StatelessWidget {
  final Widget child;

  const _SheetContainer({required this.child});

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      heightFactor: 0.92,
      child: child,
    );
  }
}

/// Layout-agnostic content of the series detail modal. Identical in
/// sheet or dialog mode.
///
/// Loads the full hierarchy via `seriesRepositoryProvider.findById`
/// when first displayed. While pending, the metadata is rendered
/// immediately ; the season list area shows a skeleton.
class SeriesDetailContent extends ConsumerStatefulWidget {
  final Series catalogSeries;

  const SeriesDetailContent({super.key, required this.catalogSeries});

  @override
  ConsumerState<SeriesDetailContent> createState() =>
      _SeriesDetailContentState();
}

class _SeriesDetailContentState extends ConsumerState<SeriesDetailContent> {
  late Future<_SeriesContext> _detailFuture;

  @override
  void initState() {
    super.initState();
    _detailFuture = _loadContext();
  }

  Future<_SeriesContext> _loadContext() async {
    final seriesRepo = ref.read(seriesRepositoryProvider);
    final progressRepo = ref.read(watchProgressRepositoryProvider);
    final session = ref.read(sessionControllerProvider);
    final profileId =
        session is ProfileSelected ? session.profile.id : null;
    final series = await seriesRepo.findById(widget.catalogSeries.id);
    EpisodeProgress? latest;
    if (profileId != null) {
      final progresses = await progressRepo.listForProfile(profileId);
      final ownIds = {
        for (final s in series.seasons) for (final e in s.episodes) e.id,
      };
      final ownEpisodes = progresses
          .whereType<EpisodeProgress>()
          .where((p) => ownIds.contains(p.episodeId))
          .toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      if (ownEpisodes.isNotEmpty) latest = ownEpisodes.first;
    }
    return _SeriesContext(series: series, latestProgress: latest);
  }

  void _retry() {
    setState(() => _detailFuture = _loadContext());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final catalogSeries = widget.catalogSeries;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Backdrop(url: catalogSeries.backdropUrl),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(catalogSeries.title, style: theme.textTheme.headlineSmall),
                if (catalogSeries.originalTitle != null &&
                    catalogSeries.originalTitle != catalogSeries.title) ...[
                  const SizedBox(height: 2),
                  Text(
                    catalogSeries.originalTitle!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontStyle: FontStyle.italic,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                if (catalogSeries.tagline != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    catalogSeries.tagline!,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontStyle: FontStyle.italic,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                _MetaLine(series: catalogSeries),
                const SizedBox(height: 16),
                if (catalogSeries.synopsis.isNotEmpty)
                  Text(catalogSeries.synopsis,
                      style: theme.textTheme.bodyMedium),
                if (catalogSeries.genres.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final g in catalogSeries.genres)
                        Chip(label: Text(g)),
                    ],
                  ),
                ],
                const SizedBox(height: 24),
                FutureBuilder<_SeriesContext>(
                  future: _detailFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    if (snapshot.hasError) {
                      return _SeasonsErrorState(onRetry: _retry);
                    }
                    final ctx = snapshot.data!;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _PlayButton(
                          series: ctx.series,
                          latestProgress: ctx.latestProgress,
                        ),
                        const SizedBox(height: 16),
                        Text('Saisons', style: theme.textTheme.titleMedium),
                        const SizedBox(height: 8),
                        _SeasonList(
                          series: ctx.series,
                          latestProgress: ctx.latestProgress,
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SeriesContext {
  final Series series;
  final EpisodeProgress? latestProgress;

  const _SeriesContext({required this.series, this.latestProgress});
}

class _PlayButton extends ConsumerWidget {
  final Series series;
  final EpisodeProgress? latestProgress;

  const _PlayButton({required this.series, this.latestProgress});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final label = playLabelFor(series: series, latestProgress: latestProgress);
    if (label == null) {
      return const SizedBox.shrink();
    }
    return FilledButton.icon(
      icon: const Icon(Icons.play_arrow_rounded),
      label: Text(label.label),
      onPressed: () {
        Navigator.of(context).pop();
        context.go('/player/episode/${label.target.id}');
      },
    );
  }
}

class _MetaLine extends StatelessWidget {
  final Series series;

  const _MetaLine({required this.series});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final parts = <String>[];
    if (series.year != null) parts.add('${series.year}');
    final seasons = series.seasonsCount;
    final episodes = series.episodesCount;
    final saisonsLabel =
        seasons <= 1 ? '$seasons saison' : '$seasons saisons';
    final episodesLabel =
        episodes <= 1 ? '$episodes épisode' : '$episodes épisodes';
    parts.add(saisonsLabel);
    parts.add(episodesLabel);
    return Text(
      parts.join(' · '),
      style: theme.textTheme.bodyMedium?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}

/// Renders the seasons sorted by `seasonNumber` ascending, EXCEPT
/// season 0 (Specials) which is moved to the end of the list.
///
/// The season of [latestProgress] (if any) is expanded by default ;
/// otherwise season 1 is. All others are collapsed.
class _SeasonList extends StatelessWidget {
  final Series series;
  final EpisodeProgress? latestProgress;

  const _SeasonList({required this.series, this.latestProgress});

  @override
  Widget build(BuildContext context) {
    final regular = series.seasons
        .where((s) => s.seasonNumber > 0)
        .toList()
      ..sort((a, b) => a.seasonNumber.compareTo(b.seasonNumber));
    final specials = series.seasons.where((s) => s.seasonNumber == 0).toList();
    final ordered = [...regular, ...specials];
    final defaultSeasonNumber = _resolveDefaultSeasonNumber(ordered);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final s in ordered)
          _SeasonSection(
            season: s,
            latestProgress: latestProgress,
            initiallyExpanded: s.seasonNumber == defaultSeasonNumber,
          ),
      ],
    );
  }

  int? _resolveDefaultSeasonNumber(List<Season> ordered) {
    final progress = latestProgress;
    if (progress != null) {
      for (final s in ordered) {
        if (s.episodes.any((e) => e.id == progress.episodeId)) {
          return s.seasonNumber;
        }
      }
    }
    final firstRegular =
        ordered.where((s) => s.seasonNumber > 0).toList();
    if (firstRegular.isEmpty) return null;
    return firstRegular.first.seasonNumber;
  }
}

class _SeasonSection extends StatelessWidget {
  final Season season;
  final EpisodeProgress? latestProgress;
  final bool initiallyExpanded;

  const _SeasonSection({
    required this.season,
    required this.initiallyExpanded,
    this.latestProgress,
  });

  @override
  Widget build(BuildContext context) {
    final label = season.isSpecials
        ? 'Specials'
        : 'Saison ${season.seasonNumber}';
    return ExpansionTile(
      initiallyExpanded: initiallyExpanded,
      title: Text(label),
      subtitle: Text(
        season.episodes.length <= 1
            ? '${season.episodes.length} épisode'
            : '${season.episodes.length} épisodes',
      ),
      children: [
        for (final ep in season.episodes)
          _EpisodeTile(
            episode: ep,
            isCurrent: latestProgress?.episodeId == ep.id,
          ),
      ],
    );
  }
}

class _EpisodeTile extends StatelessWidget {
  final Episode episode;
  final bool isCurrent;

  const _EpisodeTile({required this.episode, this.isCurrent = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ref = episode.seasonNumber == 0
        ? 'S0E${episode.episodeNumber}'
        : 'E${episode.episodeNumber}';
    return ListTile(
      leading: SizedBox(
        width: 80,
        height: 45,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: _EpisodeThumb(url: episode.thumbUrl),
        ),
      ),
      title: Text(
        '$ref · ${episode.title}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: isCurrent
            ? theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              )
            : null,
      ),
      subtitle: Text(
        formatDurationHuman(episode.duration),
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      onTap: () {
        Navigator.of(context).pop();
        context.go('/player/episode/${episode.id}');
      },
    );
  }
}

class _EpisodeThumb extends StatelessWidget {
  final String? url;

  const _EpisodeThumb({required this.url});

  @override
  Widget build(BuildContext context) {
    if (url == null || url!.isEmpty) return _ThumbFallback();
    return CachedNetworkImage(
      imageUrl: url!,
      fit: BoxFit.cover,
      placeholder: (_, _) => _ThumbFallback(),
      errorWidget: (_, _, _) => _ThumbFallback(),
    );
  }
}

class _ThumbFallback extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
    );
  }
}

class _SeasonsErrorState extends StatelessWidget {
  final VoidCallback onRetry;

  const _SeasonsErrorState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          const Text(
            'Impossible de charger les saisons.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          ElevatedButton(onPressed: onRetry, child: const Text('Réessayer')),
        ],
      ),
    );
  }
}

class _Backdrop extends StatelessWidget {
  final String? url;

  const _Backdrop({required this.url});

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
    );
    if (url == null || url!.isEmpty) {
      return AspectRatio(aspectRatio: 16 / 9, child: placeholder);
    }
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: CachedNetworkImage(
        imageUrl: url!,
        fit: BoxFit.cover,
        placeholder: (_, _) => placeholder,
        errorWidget: (_, _, _) => placeholder,
      ),
    );
  }
}
