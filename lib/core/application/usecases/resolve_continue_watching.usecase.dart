import 'dart:developer' as developer;

import 'package:kidflix/core/application/dtos/continue_watching_item.dto.dart';
import 'package:kidflix/core/application/dtos/movie.dto.dart';
import 'package:kidflix/core/domain/model/media.dart';
import 'package:kidflix/core/domain/model/watch_progress.dart';
import 'package:kidflix/core/domain/services/catalog.repository.dart';
import 'package:kidflix/core/domain/services/series.repository.dart';
import 'package:kidflix/core/domain/services/watch_progress.repository.dart';

/// Resolves the heterogeneous Continue Watching row of a profile from
/// its raw progress entries.
///
/// Algorithm (cf. `add-series-viewing/design.md` D-4):
///
/// 1. Fetch all watch progresses for the profile.
/// 2. Sort by `updatedAt` desc.
/// 3. For each progress entry, project to a [ContinueWatchingItemDto]:
///    * [MovieProgress] → resolve the [Movie] via the catalog.
///    * [EpisodeProgress] → fetch the parent [Series] via
///      [SeriesRepository.findById] and apply the next-episode rule
///      ([ContinueWatchingState]).
/// 4. Deduplicate by `seriesId` (multiple episode progresses on the
///   same series collapse to the most recent one).
/// 5. Per-item failure handling: when [SeriesRepository.findById]
///    throws, the offending entry is silently omitted ; the rest of
///    the list is unaffected.
///
/// The Continue Watching row is computed entirely client-side — the
/// backend exposes no equivalent endpoint by design (cf. `API.md`
/// § "Continue watching" note).
class ResolveContinueWatchingUseCase {
  final WatchProgressRepository _progressRepo;
  final CatalogRepository _catalogRepo;
  final SeriesRepository _seriesRepo;

  const ResolveContinueWatchingUseCase({
    required WatchProgressRepository progressRepo,
    required CatalogRepository catalogRepo,
    required SeriesRepository seriesRepo,
  })  : _progressRepo = progressRepo,
        _catalogRepo = catalogRepo,
        _seriesRepo = seriesRepo;

  Future<List<ContinueWatchingItemDto>> execute(String profileId) async {
    final progresses = await _progressRepo.listForProfile(profileId);
    final sorted = [...progresses]
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    final catalog = await _catalogRepo.listCatalog();
    final moviesById = <String, Movie>{
      for (final m in catalog.whereType<Movie>()) m.id: m,
    };

    final result = <ContinueWatchingItemDto>[];
    final seenSeriesIds = <String>{};

    for (final progress in sorted) {
      if (progress.dismissed) {
        // User explicitly removed this entry from the rail. Position is
        // preserved server-side but the row hides it until the next
        // save (which auto-resets `dismissed` on the backend).
        continue;
      }
      switch (progress) {
        case MovieProgress():
          if (progress.completed) {
            // Nothing to continue once a movie is finished.
            continue;
          }
          final movie = moviesById[progress.movieId];
          if (movie == null) {
            // Soft-deleted movie absent from /catalog: skip.
            continue;
          }
          result.add(
            MovieContinueDto(
              movie: MovieDto.fromDomain(movie),
              resumeSeconds: progress.positionSeconds,
              completed: progress.completed,
            ),
          );
        case EpisodeProgress():
          // We don't know the seriesId until we resolve the parent
          // series. The `Episode.seriesId` field is on the Episode
          // domain — but the watch progress only carries `episodeId`.
          // Inspect each loaded series to find which one owns the
          // episode. To avoid N×M lookups, we build a parent-of-episode
          // map on demand, but also handle the case where the series
          // isn't in our cache: walk through `findById` for series we
          // haven't seen.
          final episodeRef = await _resolveEpisodeWithSeries(
            episodeId: progress.episodeId,
          );
          if (episodeRef == null) continue;
          final (series, episode) = episodeRef;

          if (seenSeriesIds.contains(series.id)) {
            continue; // dedup: keep only the most recent entry per series
          }
          seenSeriesIds.add(series.id);

          final state = resolveContinueWatchingForSeries(
            series: series,
            currentEpisode: episode,
            currentProgress: progress,
          );
          if (state == null) continue;

          result.add(
            EpisodeContinueDto(
              series: series,
              episode: state.target,
              resumeSeconds: state.resumeSeconds,
              kind: state.state,
            ),
          );
      }
    }

    return result;
  }

  /// Locate the [Series] and [Episode] that own [episodeId]. Catches
  /// per-item failures and returns `null` so the caller can omit the
  /// entry from the resulting Continue Watching list.
  ///
  /// In practice the implementation iterates over all the series the
  /// app knows about — for the in-memory repo this is the seeded list,
  /// for HTTP we'd need either a `/episodes/{id}/series` endpoint
  /// (out of scope) or a brute-force walk over recent series. For MVP
  /// the contract is honored: the parent [Series] is fetched via
  /// `SeriesRepository.findById(seriesId)` once we know the id.
  ///
  /// Today we discover the seriesId via the catalog: every series in
  /// the catalog can be loaded fully via [SeriesRepository.findById].
  /// If [findById] throws for any series, that series is silently
  /// excluded from the lookup.
  Future<(Series, Episode)?> _resolveEpisodeWithSeries({
    required String episodeId,
  }) async {
    final catalog = await _catalogRepo.listCatalog();
    for (final item in catalog.whereType<Series>()) {
      try {
        final fullSeries = await _seriesRepo.findById(item.id);
        for (final season in fullSeries.seasons) {
          for (final ep in season.episodes) {
            if (ep.id == episodeId) {
              return (fullSeries, ep);
            }
          }
        }
      } catch (e, st) {
        developer.log(
          'ResolveContinueWatchingUseCase: skipping series ${item.id}',
          error: e,
          stackTrace: st,
        );
      }
    }
    return null;
  }
}

/// Pure-function helper, exposed separately so the series detail
/// modale can reuse the same logic to compute its smart "Lire" button
/// label without re-running the full Continue Watching pipeline.
///
/// Returns `null` when the resolution is impossible (e.g. the series
/// has zero non-Specials episodes, which shouldn't happen but guards
/// against edge cases).
ContinueWatchingResolution? resolveContinueWatchingForSeries({
  required Series series,
  required Episode currentEpisode,
  required EpisodeProgress currentProgress,
}) {
  if (!currentProgress.completed) {
    return ContinueWatchingResolution(
      state: ContinueWatchingState.inProgress,
      target: currentEpisode,
      resumeSeconds: currentProgress.positionSeconds,
    );
  }

  final next = findNextEpisode(series, after: currentEpisode);
  if (next != null) {
    return ContinueWatchingResolution(
      state: ContinueWatchingState.nextAfterCompleted,
      target: next,
      resumeSeconds: 0,
    );
  }

  // End of series — restart from the first episode of the lowest
  // non-Specials season.
  final firstEp = firstNonSpecialsEpisode(series);
  if (firstEp == null) return null;
  return ContinueWatchingResolution(
    state: ContinueWatchingState.restart,
    target: firstEp,
    resumeSeconds: 0,
  );
}

/// Finds the next episode in the series rotation after [after].
///
/// Specials (season 0) are excluded from the rotation: completing the
/// last episode of season 1 does NOT lead to season 0, but to season 2
/// if it exists, otherwise [null] (end of series).
Episode? findNextEpisode(Series series, {required Episode after}) {
  final seasons = series.seasons
      .where((s) => s.seasonNumber > 0)
      .toList()
    ..sort((a, b) => a.seasonNumber.compareTo(b.seasonNumber));

  if (after.seasonNumber == 0) {
    // Completed a Specials episode → behave as "end of Specials": no
    // forward rotation. We don't enumerate Specials in sequence.
    return null;
  }

  final currentSeasonIdx = seasons.indexWhere(
    (s) => s.seasonNumber == after.seasonNumber,
  );
  if (currentSeasonIdx == -1) return null;
  final currentSeason = seasons[currentSeasonIdx];

  final episodesSorted = [...currentSeason.episodes]
    ..sort((a, b) => a.episodeNumber.compareTo(b.episodeNumber));
  final epIdx = episodesSorted.indexWhere((e) => e.id == after.id);
  if (epIdx >= 0 && epIdx + 1 < episodesSorted.length) {
    return episodesSorted[epIdx + 1];
  }

  if (currentSeasonIdx + 1 < seasons.length) {
    final nextSeason = seasons[currentSeasonIdx + 1];
    final nextEpsSorted = [...nextSeason.episodes]
      ..sort((a, b) => a.episodeNumber.compareTo(b.episodeNumber));
    if (nextEpsSorted.isNotEmpty) return nextEpsSorted.first;
  }

  return null;
}

/// Finds the previous episode in the series rotation before [before].
///
/// Symmetric to [findNextEpisode]: Specials (season 0) excluded; walks
/// back within the season, then to the last episode of the previous
/// season, returning `null` at the start of the rotation.
Episode? findPreviousEpisode(Series series, {required Episode before}) {
  final seasons = series.seasons
      .where((s) => s.seasonNumber > 0)
      .toList()
    ..sort((a, b) => a.seasonNumber.compareTo(b.seasonNumber));

  if (before.seasonNumber == 0) return null;

  final currentSeasonIdx = seasons.indexWhere(
    (s) => s.seasonNumber == before.seasonNumber,
  );
  if (currentSeasonIdx == -1) return null;
  final currentSeason = seasons[currentSeasonIdx];

  final episodesSorted = [...currentSeason.episodes]
    ..sort((a, b) => a.episodeNumber.compareTo(b.episodeNumber));
  final epIdx = episodesSorted.indexWhere((e) => e.id == before.id);
  if (epIdx > 0) {
    return episodesSorted[epIdx - 1];
  }

  if (currentSeasonIdx - 1 >= 0) {
    final prevSeason = seasons[currentSeasonIdx - 1];
    final prevEpsSorted = [...prevSeason.episodes]
      ..sort((a, b) => a.episodeNumber.compareTo(b.episodeNumber));
    if (prevEpsSorted.isNotEmpty) return prevEpsSorted.last;
  }

  return null;
}

/// Flattened list of episodes in the rotation order: seasons ≥ 1 sorted
/// ascending by `seasonNumber`, episodes sorted by `episodeNumber`.
/// Specials (season 0) are excluded, matching [findNextEpisode] /
/// [findPreviousEpisode].
List<Episode> flatRotationEpisodes(Series series) {
  final seasons = series.seasons
      .where((s) => s.seasonNumber > 0)
      .toList()
    ..sort((a, b) => a.seasonNumber.compareTo(b.seasonNumber));
  final episodes = <Episode>[];
  for (final season in seasons) {
    final eps = [...season.episodes]
      ..sort((a, b) => a.episodeNumber.compareTo(b.episodeNumber));
    episodes.addAll(eps);
  }
  return episodes;
}

/// First episode of the lowest non-Specials season (typically S1E1).
Episode? firstNonSpecialsEpisode(Series series) {
  final episodes = flatRotationEpisodes(series);
  return episodes.isEmpty ? null : episodes.first;
}

/// Result of [resolveContinueWatchingForSeries]: the next episode the
/// user should watch and how to label / resume it.
class ContinueWatchingResolution {
  final ContinueWatchingState state;
  final Episode target;
  final int resumeSeconds;

  const ContinueWatchingResolution({
    required this.state,
    required this.target,
    required this.resumeSeconds,
  });
}
