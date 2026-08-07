import 'package:kidflix/core/application/dtos/continue_watching_item.dto.dart';
import 'package:kidflix/core/application/dtos/movie.dto.dart';
import 'package:kidflix/core/application/services/logger_application.service.dart';
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
/// 3. Resolve, in ONE batch, the parent series of every episode entry
///    (cf. [_resolveEpisodeParents]).
/// 4. For each progress entry, project to a [ContinueWatchingItemDto]:
///    * [MovieProgress] → resolve the [Movie] via the catalog.
///    * [EpisodeProgress] → apply the next-episode rule
///      ([ContinueWatchingState]) on the resolved parent.
/// 5. Deduplicate by `seriesId` (multiple episode progresses on the
///   same series collapse to the most recent one).
/// 6. Per-item failure handling: when [SeriesRepository.findById]
///    throws, the offending entry is silently omitted ; the rest of
///    the list is unaffected.
///
/// The Continue Watching row is computed entirely client-side — the
/// backend exposes no equivalent endpoint by design (cf. `API.md`
/// § "Continue watching" note).
///
/// ## Network shape
///
/// This use case used to be the app's dominant source of latency: it
/// re-fetched `/catalog` and then walked `GET /series/{id}` over the
/// WHOLE catalog, sequentially, **once per episode progress** — an N×M
/// round-trip fan-out that pushed the home to ~10 s while `/catalog`
/// itself answered in under 70 ms. Production logs showed every series
/// of the catalog being fetched 60+ times an hour.
///
/// Two invariants keep that from coming back:
///
/// * [execute] never fetches what the caller already has — pass
///   `catalog` and `progresses` (the home does, cf.
///   `CatalogApplicationService.buildHomeRowsFor`).
/// * Series resolution is batched and deduplicated across the whole
///   call, never nested inside the per-progress loop.
class ResolveContinueWatchingUseCase {
  final WatchProgressRepository _progressRepo;
  final CatalogRepository _catalogRepo;
  final SeriesRepository _seriesRepo;
  final LoggerApplicationService _logger;

  /// Episode → parent series, learned from resolutions already done.
  ///
  /// An episode never changes parent, so this is safe to keep for the
  /// lifetime of the use case (the provider is `keepAlive`, so that is
  /// the app session). It caches the *id* only, never the [Series]
  /// object: the next load re-fetches the series through the normal fast
  /// path and so never serves stale seasons or episodes.
  ///
  /// Its job is to make the fallback walk a once-per-session cost
  /// instead of a once-per-home-load one, for entries the backfill
  /// (`WatchProgressSyncService.backfillSeriesIds`) has not reached —
  /// the first load after launch, or a progress that only ever existed
  /// locally.
  final Map<String, String> _seriesIdByEpisodeId = {};

  ResolveContinueWatchingUseCase({
    required WatchProgressRepository progressRepo,
    required CatalogRepository catalogRepo,
    required SeriesRepository seriesRepo,
    required LoggerApplicationService logger,
  }) : _progressRepo = progressRepo,
       _catalogRepo = catalogRepo,
       _seriesRepo = seriesRepo,
       _logger = logger;

  /// [catalog] and [progresses] let the caller hand over data it has
  /// already loaded. Both are fetched on demand when omitted, so a
  /// standalone call still works — but the home path supplies them and
  /// thereby spares a duplicate `/catalog` and `/progress` round-trip
  /// each.
  Future<List<ContinueWatchingItemDto>> execute(
    String profileId, {
    List<CatalogItem>? catalog,
    List<WatchProgress>? progresses,
  }) async {
    final allProgresses =
        progresses ?? await _progressRepo.listForProfile(profileId);
    final sorted = [...allProgresses]
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    final items = catalog ?? await _catalogRepo.listCatalog();
    final moviesById = <String, Movie>{
      for (final m in items.whereType<Movie>()) m.id: m,
    };

    // One batch for every episode entry, before the projection loop —
    // the loop itself must stay free of any await on the network.
    final episodeParents = await _resolveEpisodeParents(
      sorted.whereType<EpisodeProgress>().where((p) => !p.dismissed),
      items.whereType<Series>().toList(growable: false),
    );

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
          // Already resolved in batch above — no network here.
          final episodeRef = episodeParents[progress.episodeId];
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

  /// Maps every episode id in [progresses] to its parent `(Series,
  /// Episode)`, in a single batch. Entries that cannot be resolved are
  /// absent from the result and get dropped by the caller.
  ///
  /// Two paths, and which one runs is what decides the cost of the whole
  /// home load:
  ///
  /// * **Fast** — [EpisodeProgress.seriesId] is known (the backend sends
  ///   `series_id` on every episode progress, cf. `API.md`
  ///   § Progression de lecture). Only the distinct series actually
  ///   referenced are fetched, concurrently. Typically 1–2 requests.
  /// * **Fallback** — at least one entry has no `seriesId` and none was
  ///   learned earlier in the session. The whole catalog is then loaded
  ///   to build the index. Still ONE pass for the entire call,
  ///   concurrent, and shared by every unresolved entry — where the
  ///   previous implementation restarted a sequential walk for each one.
  ///   Whatever it discovers is remembered in [_seriesIdByEpisodeId], so
  ///   a session pays this at most once.
  ///
  /// [catalogSeries] is only read for the fallback ; the fast path never
  /// touches it.
  Future<Map<String, (Series, Episode)>> _resolveEpisodeParents(
    Iterable<EpisodeProgress> progresses,
    List<Series> catalogSeries,
  ) async {
    final pending = progresses.toList(growable: false);
    if (pending.isEmpty) return const {};

    // The backend's pointer wins ; the session cache covers the entries
    // it has not reached yet.
    final seriesIdFor = <String, String>{
      for (final p in pending)
        p.episodeId: ?(p.seriesId ?? _seriesIdByEpisodeId[p.episodeId]),
    };
    final needsFallback = pending.any(
      (p) => !seriesIdFor.containsKey(p.episodeId),
    );
    final loaded = await _loadSeries({
      ...seriesIdFor.values,
      if (needsFallback) ...catalogSeries.map((s) => s.id),
    });

    final out = <String, (Series, Episode)>{};
    for (final progress in pending) {
      final seriesId = seriesIdFor[progress.episodeId];
      if (seriesId != null) {
        // Trust the pointer. A miss here means the series failed to load
        // (already logged) or the pointer is stale — either way,
        // scanning the rest would not be more correct.
        final series = loaded[seriesId];
        if (series == null) continue;
        final episode = _findEpisodeIn(series, progress.episodeId);
        if (episode != null) out[progress.episodeId] = (series, episode);
        continue;
      }
      for (final series in loaded.values) {
        final episode = _findEpisodeIn(series, progress.episodeId);
        if (episode != null) {
          out[progress.episodeId] = (series, episode);
          _seriesIdByEpisodeId[progress.episodeId] = series.id;
          break;
        }
      }
    }
    return out;
  }

  /// Loads [ids] concurrently. A series that fails to load is logged and
  /// omitted — one unreachable series never sinks the whole row.
  ///
  /// The fan-out is bounded by the catalog size in the fallback path,
  /// which is acceptable because that path is transitional: once every
  /// stored progress carries a `seriesId`, only the handful of series on
  /// the rail are ever fetched.
  Future<Map<String, Series>> _loadSeries(Set<String> ids) async {
    if (ids.isEmpty) return const {};
    final ordered = ids.toList(growable: false);
    final loaded = await Future.wait(
      ordered.map((id) async {
        try {
          return await _seriesRepo.findById(id);
        } catch (e) {
          await _logger.warn(
            'continue_watching.series_skipped',
            attrs: {'series.id': id},
            error: e,
          );
          return null;
        }
      }),
    );
    return {
      for (var i = 0; i < ordered.length; i++) ordered[i]: ?loaded[i],
    };
  }

  Episode? _findEpisodeIn(Series series, String episodeId) {
    for (final season in series.seasons) {
      for (final episode in season.episodes) {
        if (episode.id == episodeId) return episode;
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
  final seasons = series.seasons.where((s) => s.seasonNumber > 0).toList()
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
  final seasons = series.seasons.where((s) => s.seasonNumber > 0).toList()
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
  final seasons = series.seasons.where((s) => s.seasonNumber > 0).toList()
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
