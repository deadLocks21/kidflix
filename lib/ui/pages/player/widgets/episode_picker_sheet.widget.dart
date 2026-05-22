import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:kidflix/core/domain/model/media.dart';
import 'package:kidflix/core/domain/model/watch_progress.dart';
import 'package:kidflix/shared/duration_format.dart';
import 'package:kidflix/ui/pages/home/widgets/resume_progress_bar.widget.dart';
import 'package:kidflix/ui/theme/kidflix_palette.dart';

/// Opens a dark-themed bottom sheet listing the series' episodes,
/// grouped by season. Returns the selected episode id, or `null` if
/// the user dismisses the sheet.
///
/// Read-only by design — no download buttons, no metadata edits. The
/// caller (the player) is responsible for the actual switch.
Future<String?> showEpisodePickerSheet(
  BuildContext context, {
  required Series series,
  required String currentEpisodeId,
  required Map<String, EpisodeProgress> progressByEpisodeId,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.black,
    showDragHandle: true,
    builder: (_) => FractionallySizedBox(
      heightFactor: 0.9,
      child: _EpisodePickerContent(
        series: series,
        currentEpisodeId: currentEpisodeId,
        progressByEpisodeId: progressByEpisodeId,
      ),
    ),
  );
}

class _EpisodePickerContent extends StatefulWidget {
  final Series series;
  final String currentEpisodeId;
  final Map<String, EpisodeProgress> progressByEpisodeId;

  const _EpisodePickerContent({
    required this.series,
    required this.currentEpisodeId,
    required this.progressByEpisodeId,
  });

  @override
  State<_EpisodePickerContent> createState() => _EpisodePickerContentState();
}

class _EpisodePickerContentState extends State<_EpisodePickerContent> {
  final GlobalKey _currentTileKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    // Wait until the ExpansionTile's open animation has settled, then
    // bring the current episode tile into view. Without the delay, the
    // tile's RenderObject isn't laid out yet and ensureVisible no-ops.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future<void>.delayed(const Duration(milliseconds: 280));
      if (!mounted) return;
      final ctx = _currentTileKey.currentContext;
      if (ctx == null) return;
      // currentContext is the tile's own BuildContext, not the State's
      // — the unrelated-mounted lint here is a false positive. We guard
      // tile lifetime with the null check above and the State's with
      // [mounted].
      await Scrollable.ensureVisible(
        // ignore: use_build_context_synchronously
        ctx,
        duration: const Duration(milliseconds: 250),
        alignment: 0.3,
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final regular =
        widget.series.seasons.where((s) => s.seasonNumber > 0).toList()
          ..sort((a, b) => a.seasonNumber.compareTo(b.seasonNumber));
    final specials = widget.series.seasons
        .where((s) => s.seasonNumber == 0)
        .toList();
    final ordered = [...regular, ...specials];
    final currentSeasonNumber = _seasonNumberOf(
      widget.currentEpisodeId,
      ordered,
    );

    return Theme(
      data: ThemeData.dark(useMaterial3: true).copyWith(
        scaffoldBackgroundColor: Colors.black,
        canvasColor: Colors.black,
      ),
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Text(
              widget.series.title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          for (final s in ordered)
            _SeasonSection(
              season: s,
              currentEpisodeId: widget.currentEpisodeId,
              progressByEpisodeId: widget.progressByEpisodeId,
              initiallyExpanded: s.seasonNumber == currentSeasonNumber,
              currentTileKey: _currentTileKey,
            ),
        ],
      ),
    );
  }

  int? _seasonNumberOf(String episodeId, List<Season> seasons) {
    for (final s in seasons) {
      if (s.episodes.any((e) => e.id == episodeId)) return s.seasonNumber;
    }
    return seasons.isNotEmpty ? seasons.first.seasonNumber : null;
  }
}

class _SeasonSection extends StatelessWidget {
  final Season season;
  final String currentEpisodeId;
  final Map<String, EpisodeProgress> progressByEpisodeId;
  final bool initiallyExpanded;
  final Key? currentTileKey;

  const _SeasonSection({
    required this.season,
    required this.currentEpisodeId,
    required this.progressByEpisodeId,
    required this.initiallyExpanded,
    this.currentTileKey,
  });

  @override
  Widget build(BuildContext context) {
    final label = season.isSpecials
        ? 'Specials'
        : 'Saison ${season.seasonNumber}';
    return ExpansionTile(
      initiallyExpanded: initiallyExpanded,
      collapsedIconColor: Colors.white70,
      iconColor: Colors.white,
      title: Text(label, style: const TextStyle(color: Colors.white)),
      subtitle: Text(
        season.episodes.length <= 1
            ? '${season.episodes.length} épisode'
            : '${season.episodes.length} épisodes',
        style: const TextStyle(color: Colors.white70),
      ),
      children: [
        for (final ep in season.episodes)
          _EpisodeTile(
            key: ep.id == currentEpisodeId ? currentTileKey : null,
            episode: ep,
            progress: progressByEpisodeId[ep.id],
            isCurrent: ep.id == currentEpisodeId,
          ),
      ],
    );
  }
}

class _EpisodeTile extends StatelessWidget {
  final Episode episode;
  final EpisodeProgress? progress;
  final bool isCurrent;

  const _EpisodeTile({
    super.key,
    required this.episode,
    required this.isCurrent,
    this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final epRef = episode.seasonNumber == 0
        ? 'S0E${episode.episodeNumber}'
        : 'E${episode.episodeNumber}';
    final isWatched = progress?.completed ?? false;
    final totalSeconds = episode.duration.inSeconds;
    final inProgress =
        progress != null &&
        !progress!.completed &&
        progress!.positionSeconds > 0 &&
        totalSeconds > 0;

    final titleColor = isCurrent
        ? KidflixPalette.red
        : (isWatched ? Colors.white60 : Colors.white);

    return ListTile(
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
                child: _Thumb(url: episode.thumbUrl),
              ),
              if (isCurrent)
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: KidflixPalette.red, width: 2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.play_arrow_rounded,
                    color: Colors.white,
                  ),
                ),
              if (inProgress)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: ResumeProgressBar(
                    progress: progress!.positionSeconds / totalSeconds,
                  ),
                ),
            ],
          ),
        ),
      ),
      title: Text(
        '$epRef · ${episode.title}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: titleColor),
      ),
      subtitle: Text(
        formatDurationHuman(episode.duration),
        style: const TextStyle(color: Colors.white60),
      ),
      onTap: isCurrent
          ? null
          : () => Navigator.of(context).pop<String>(episode.id),
    );
  }
}

class _Thumb extends StatelessWidget {
  final String? url;

  const _Thumb({required this.url});

  @override
  Widget build(BuildContext context) {
    final fallback = Container(color: Colors.white12);
    if (url == null || url!.isEmpty) return fallback;
    return CachedNetworkImage(
      imageUrl: url!,
      fit: BoxFit.cover,
      placeholder: (_, _) => fallback,
      errorWidget: (_, _, _) => fallback,
    );
  }
}
