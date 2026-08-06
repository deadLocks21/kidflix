import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kidflix/core/application/session_state.dart';
import 'package:kidflix/core/application/usecases/pick_next_shuffle_episode.usecase.dart';
import 'package:kidflix/core/domain/model/cached_cast_member.dart';
import 'package:kidflix/core/domain/model/media.dart';
import 'package:kidflix/core/domain/model/watch_progress.dart';
import 'package:kidflix/infrastructure/providers/download.repository_provider.dart';
import 'package:kidflix/infrastructure/providers/series.repository_provider.dart';
import 'package:kidflix/infrastructure/providers/session.controller_provider.dart';
import 'package:kidflix/infrastructure/providers/watch_progress.repository_provider.dart';
import 'package:kidflix/shared/duration_format.dart';
import 'package:kidflix/shared/tmdb_image.dart';
import 'package:kidflix/ui/focus/horizontal_focus_fence.widget.dart';
import 'package:kidflix/ui/focus/kidflix_focus_zoom.widget.dart';
import 'package:kidflix/ui/pages/home/widgets/download_intent_button.widget.dart';
import 'package:kidflix/ui/pages/home/widgets/favorite_button.widget.dart';
import 'package:kidflix/ui/pages/home/widgets/resume_progress_bar.widget.dart';
import 'package:kidflix/ui/pages/home/widgets/season_download_button.widget.dart';
import 'package:kidflix/ui/pages/home/widgets/series/play_label.dart';
import 'package:kidflix/ui/pages/home/widgets/trailer_header.widget.dart';
import 'package:kidflix/ui/pages/remote/cast_playback.dart';

const double _adaptiveBreakpointDp = 600;

/// Room between the series play button and "Aléatoire".
///
/// Wide enough to swallow the play button's focus zoom: at 6 % of a
/// button that stretches to fill the row, that is a good dozen points on
/// each side, and a 12 pt gap had it painting over its neighbour. Guarded
/// by a test, since the number only makes sense next to the scale.
const double _playRowGap = 28;

/// Opens the series detail modal for [series], choosing adaptive
/// presentation:
///
/// - width `< 600 dp` → full-height [ModalBottomSheet]
/// - width `>= 600 dp` → centered [Dialog] capped at 720 dp wide
///
/// The modal triggers a fetch of the full series tree (with seasons +
/// episodes) on open via `seriesRepositoryProvider.findById` — the
/// [series] argument is the catalog projection (no episodes).
Future<void> showSeriesDetailModal(BuildContext context, Series series) async {
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
    return FractionallySizedBox(heightFactor: 0.92, child: child);
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
    final profileId = session is ProfileSelected ? session.profile.id : null;
    // When the catalog projection already carries the full seasons tree
    // (offline catalog reconstructed from the manifest) we skip the
    // network fetch entirely — `findById` would fail offline anyway.
    final Series series;
    if (widget.catalogSeries.seasons.isNotEmpty) {
      series = widget.catalogSeries;
    } else {
      series = await seriesRepo.findById(widget.catalogSeries.id);
    }
    // Snapshot the full series under the manifest's `series/` namespace
    // so the offline catalog can rebuild the series card and detail
    // modal for any downloaded episode of this series. Best-effort.
    unawaited(_persistSeriesSnapshot(series));
    EpisodeProgress? latest;
    var progressByEpisodeId = const <String, EpisodeProgress>{};
    if (profileId != null) {
      final progresses = await progressRepo.listForProfile(profileId);
      final ownIds = {
        for (final s in series.seasons)
          for (final e in s.episodes) e.id,
      };
      final ownEpisodes =
          progresses
              .whereType<EpisodeProgress>()
              .where((p) => ownIds.contains(p.episodeId))
              .toList()
            ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      if (ownEpisodes.isNotEmpty) latest = ownEpisodes.first;
      progressByEpisodeId = {for (final p in ownEpisodes) p.episodeId: p};
    }
    return _SeriesContext(
      series: series,
      latestProgress: latest,
      progressByEpisodeId: progressByEpisodeId,
    );
  }

  Future<void> _persistSeriesSnapshot(Series series) async {
    try {
      await ref
          .read(downloadRepositoryProvider)
          .cacheSeriesMetadata(
            seriesId: series.id,
            title: series.title,
            posterUrl: series.posterUrl,
            originalTitle: series.originalTitle,
            year: series.year,
            ageCategory: series.ageCategory.name,
            synopsis: series.synopsis,
            tagline: series.tagline,
            backdropUrl: series.backdropUrl,
            logoUrl: series.logoUrl,
            genres: series.genres,
            director: series.director,
            topCast: [
              for (final c in series.cast.take(5))
                CachedCastMember(
                  name: c.name,
                  role: c.role,
                  photoUrl: c.photoUrl,
                ),
            ],
            seasonsCount: series.seasonsCount,
            episodesCount: series.episodesCount,
          );
    } catch (_) {
      // Best-effort.
    }
  }

  void _retry() {
    setState(() => _detailFuture = _loadContext());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final catalogSeries = widget.catalogSeries;
    // One scope for the whole modal, so every episode row's fence shares
    // a single traversal policy — and therefore a single, coherent
    // direction history.
    return HorizontalFocusFenceScope(
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                TrailerHeader(
                  trailerUrl: catalogSeries.trailerUrl,
                  fallbackImageUrl: catalogSeries.backdropUrl,
                  logoUrl: catalogSeries.logoUrl,
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: KidflixFocusZoom(
                    child: IconButton.filled(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    catalogSeries.title,
                    style: theme.textTheme.headlineSmall,
                  ),
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
                  Row(
                    children: [
                      Expanded(child: _MetaLine(series: catalogSeries)),
                      FavoriteButton(
                        target: SeriesFavoriteTarget(catalogSeries.id),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (catalogSeries.synopsis.isNotEmpty)
                    Text(
                      catalogSeries.synopsis,
                      style: theme.textTheme.bodyMedium,
                    ),
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
                            progressByEpisodeId: ctx.progressByEpisodeId,
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
      ),
    );
  }
}

class _SeriesContext {
  final Series series;
  final EpisodeProgress? latestProgress;
  final Map<String, EpisodeProgress> progressByEpisodeId;

  const _SeriesContext({
    required this.series,
    this.latestProgress,
    this.progressByEpisodeId = const {},
  });
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
    final shufflePick = pickNextShuffleEpisode(
      series: series,
      alreadyPlayedIds: const {},
    );
    return Row(
      children: [
        Expanded(
          // Stretched, and zoomed all the same: [_playRowGap] is sized so
          // the growth lands in the gap rather than over its neighbour.
          // That is the whole rule for a wide button — the form submit
          // buttons keep the ring alone because a stretch column leaves
          // them nothing to grow into.
          child: KidflixFocusZoom(
            child: FilledButton.icon(
              // Entry point for the keyboard, as in the movie modal.
              autofocus: true,
              icon: Icon(
                castTargetName(ref) == null
                    ? Icons.play_arrow_rounded
                    : Icons.cast_connected,
              ),
              label: Text(label.label),
              onPressed: () async {
                final cast = await castIfRemoting(
                  context,
                  ref,
                  mediaId: label.target.id,
                  isEpisode: true,
                  seriesId: series.id,
                );
                if (!context.mounted) return;
                Navigator.of(context).pop();
                if (cast) return;
                context.go(
                  '/player/episode/${label.target.id}?series=${series.id}',
                );
              },
            ),
          ),
        ),
        if (shufflePick != null) ...[
          const SizedBox(width: _playRowGap),
          KidflixFocusZoom(
            child: OutlinedButton.icon(
              icon: const Icon(Icons.shuffle_rounded),
              label: const Text('Aléatoire'),
              onPressed: () async {
                final cast = await castIfRemoting(
                  context,
                  ref,
                  mediaId: shufflePick.id,
                  isEpisode: true,
                  seriesId: series.id,
                  shuffle: true,
                );
                if (!context.mounted) return;
                Navigator.of(context).pop();
                if (cast) return;
                context.go(
                  '/player/episode/${shufflePick.id}'
                  '?series=${series.id}&mode=shuffle',
                );
              },
            ),
          ),
        ],
      ],
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
    final saisonsLabel = seasons <= 1 ? '$seasons saison' : '$seasons saisons';
    final episodesLabel = episodes <= 1
        ? '$episodes épisode'
        : '$episodes épisodes';
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
  final Map<String, EpisodeProgress> progressByEpisodeId;

  const _SeasonList({
    required this.series,
    this.latestProgress,
    this.progressByEpisodeId = const {},
  });

  @override
  Widget build(BuildContext context) {
    final regular = series.seasons.where((s) => s.seasonNumber > 0).toList()
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
            seriesTitle: series.title,
            progressByEpisodeId: progressByEpisodeId,
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
    final firstRegular = ordered.where((s) => s.seasonNumber > 0).toList();
    if (firstRegular.isEmpty) return null;
    return firstRegular.first.seasonNumber;
  }
}

/// One season: a header that folds the episode list, and the season's
/// own download action.
///
/// Not an [ExpansionTile]. That widget builds its header as a single
/// tappable tile, and anything placed inside it — the download button —
/// becomes a focusable nested in a focusable, which directional traversal
/// cannot reach: only Tab could. Splitting the header into two sibling
/// buttons gives the season row the same grammar as an episode row,
/// sideways between the two actions, vertically to the next line.
class _SeasonSection extends StatefulWidget {
  final Season season;
  final String seriesTitle;
  final Map<String, EpisodeProgress> progressByEpisodeId;
  final bool initiallyExpanded;

  const _SeasonSection({
    required this.season,
    required this.seriesTitle,
    required this.initiallyExpanded,
    this.progressByEpisodeId = const {},
  });

  @override
  State<_SeasonSection> createState() => _SeasonSectionState();
}

class _SeasonSectionState extends State<_SeasonSection> {
  static const Duration _foldDuration = Duration(milliseconds: 200);

  late bool _expanded = widget.initiallyExpanded;

  void _toggle() => setState(() => _expanded = !_expanded);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final season = widget.season;
    final label = season.isSpecials
        ? 'Specials'
        : 'Saison ${season.seasonNumber}';
    final count = season.episodes.length <= 1
        ? '${season.episodes.length} épisode'
        : '${season.episodes.length} épisodes';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HorizontalFocusFence(
          child: Row(
            children: [
              Expanded(
                child: Semantics(
                  expanded: _expanded,
                  child: TextButton(
                    onPressed: _toggle,
                    style: TextButton.styleFrom(
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      foregroundColor: theme.colorScheme.onSurface,
                    ),
                    child: Row(
                      children: [
                        AnimatedRotation(
                          turns: _expanded ? 0.5 : 0,
                          duration: _foldDuration,
                          child: const Icon(Icons.expand_more),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: label,
                                  style: theme.textTheme.titleMedium,
                                ),
                                TextSpan(
                                  text: ' · $count',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (season.episodes.isNotEmpty)
                SeasonDownloadButton(
                  seriesId: season.episodes.first.seriesId,
                  seasonNumber: season.seasonNumber,
                  episodeIds: season.episodes
                      .map((e) => e.id)
                      .toList(growable: false),
                ),
              const SizedBox(width: 8),
            ],
          ),
        ),
        // Collapsed means not built, so a folded season contributes no
        // focus stops — same as the tile this replaces.
        AnimatedSize(
          duration: _foldDuration,
          curve: Curves.easeInOut,
          alignment: Alignment.topCenter,
          child: _expanded
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final ep in season.episodes)
                      _EpisodeTile(
                        episode: ep,
                        parentSeriesTitle: widget.seriesTitle,
                        progress: widget.progressByEpisodeId[ep.id],
                      ),
                  ],
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}

class _EpisodeTile extends ConsumerStatefulWidget {
  final Episode episode;
  final String parentSeriesTitle;
  final EpisodeProgress? progress;

  const _EpisodeTile({
    required this.episode,
    required this.parentSeriesTitle,
    this.progress,
  });

  @override
  ConsumerState<_EpisodeTile> createState() => _EpisodeTileState();
}

class _EpisodeTileState extends ConsumerState<_EpisodeTile> {
  String get _epRef => widget.episode.seasonNumber == 0
      ? 'S0E${widget.episode.episodeNumber}'
      : 'E${widget.episode.episodeNumber}';

  Future<void> _play() async {
    final episode = widget.episode;
    // Pre-cache so the manager resolves this episode regardless
    // of the parent's /catalog visibility, AND so the offline
    // series detail modal can rebuild the seasons tree.
    unawaited(
      ref
          .read(downloadRepositoryProvider)
          .cacheMediaMetadata(
            mediaId: episode.id,
            isEpisode: true,
            title: '$_epRef · ${episode.title}',
            posterUrl: episode.thumbUrl,
            parentSeriesTitle: widget.parentSeriesTitle,
            originalTitle: episode.originalTitle,
            durationSeconds: episode.duration.inSeconds,
            ageCategory: episode.ageCategory.name,
            synopsis: episode.synopsis,
            seriesId: episode.seriesId,
            seasonNumber: episode.seasonNumber,
            episodeNumber: episode.episodeNumber,
          ),
    );
    final cast = await castIfRemoting(
      context,
      ref,
      mediaId: episode.id,
      isEpisode: true,
      seriesId: episode.seriesId,
    );
    if (!mounted) return;
    Navigator.of(context).pop();
    if (cast) return;
    context.go('/player/episode/${episode.id}?series=${episode.seriesId}');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final episode = widget.episode;
    final progress = widget.progress;
    final isWatched = progress?.completed ?? false;
    final totalSeconds = episode.duration.inSeconds;
    final inProgress =
        progress != null &&
        !progress.completed &&
        progress.positionSeconds > 0 &&
        totalSeconds > 0;
    // A plain [GestureDetector] rather than `ListTile.onTap`: the tile
    // would hand its node to an [InkWell], and an [InkWell] overwrites
    // `canRequestFocus` and `skipTraversal` on whatever node it is given.
    // There is no way to keep its tap and refuse its focus stop. This
    // gives up the row's ripple, and nothing else — the two buttons carry
    // the keyboard.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _play,
      child: ListTile(
        leading: SizedBox(
          width: 80,
          height: 45,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Opacity(
                  opacity: isWatched ? 0.5 : 1.0,
                  child: _EpisodeThumb(url: episode.thumbUrl),
                ),
                if (inProgress)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: ResumeProgressBar(
                      progress: progress.positionSeconds / totalSeconds,
                    ),
                  ),
              ],
            ),
          ),
        ),
        title: Text(
          '$_epRef · ${episode.title}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: isWatched
              ? theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                )
              : null,
        ),
        subtitle: Text(
          formatDurationHuman(episode.duration),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        // Fenced: sideways stays between these two buttons. Without it,
        // right of "Télécharger" is the modal's close button, which by
        // then is scrolled off the top of the sheet.
        trailing: HorizontalFocusFence(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              KidflixFocusZoom(
                child: IconButton.filled(
                  tooltip: 'Lire',
                  icon: const Icon(Icons.play_arrow_rounded),
                  onPressed: _play,
                ),
              ),
              const SizedBox(width: 4),
              DownloadIntentButton(
                mediaId: episode.id,
                isEpisode: true,
                compact: true,
                title: '$_epRef · ${episode.title}',
                posterUrl: episode.thumbUrl,
                parentSeriesTitle: widget.parentSeriesTitle,
                originalTitle: episode.originalTitle,
                durationSeconds: episode.duration.inSeconds,
                ageCategory: episode.ageCategory.name,
                synopsis: episode.synopsis,
                seriesId: episode.seriesId,
                seasonNumber: episode.seasonNumber,
                episodeNumber: episode.episodeNumber,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EpisodeThumb extends StatelessWidget {
  final String? url;

  const _EpisodeThumb({required this.url});

  @override
  Widget build(BuildContext context) {
    if (url == null || url!.isEmpty) return _ThumbFallback();
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return CachedNetworkImage(
      imageUrl: tmdbResize(url!, 'w185'),
      fit: BoxFit.cover,
      filterQuality: FilterQuality.medium,
      memCacheWidth: (80 * dpr).round(),
      memCacheHeight: (45 * dpr).round(),
      placeholder: (_, _) => _ThumbFallback(),
      errorWidget: (_, _, _) => _ThumbFallback(),
    );
  }
}

class _ThumbFallback extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(color: Theme.of(context).colorScheme.surfaceContainerHigh);
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
