import 'dart:async';

import 'package:kidflix/core/domain/model/download_kind.dart';
import 'package:kidflix/core/domain/model/episode_download.dart';
import 'package:kidflix/core/domain/model/media.dart';
import 'package:kidflix/core/domain/model/movie_download.dart';
import 'package:kidflix/core/domain/services/download.repository.dart';
import 'package:kidflix/core/domain/services/series.repository.dart';

/// Snapshot of a season-download in progress: how many episodes were
/// completed so far, which episode is currently being downloaded, and
/// the latest snapshot of that episode's transfer.
class DownloadSeasonProgress {
  final int totalEpisodes;
  final int doneEpisodes;
  final String currentEpisodeId;
  final EpisodeDownload currentSnapshot;

  const DownloadSeasonProgress({
    required this.totalEpisodes,
    required this.doneEpisodes,
    required this.currentEpisodeId,
    required this.currentSnapshot,
  });

  bool get allDone => doneEpisodes == totalEpisodes;
}

/// Sequentially downloads every episode of a season, marking each as
/// `kind=download` once it completes. Aborts on per-episode failure or
/// cancellation. Skips episodes that already exist on disk in
/// `kind=download`; promotes episodes that already exist in
/// `kind=cache` (no HTTP).
///
/// Cancelling the consuming subscription cancels the in-flight episode
/// download (`cancelEpisode`) and stops the loop.
class DownloadSeasonUseCase {
  final SeriesRepository _series;
  final DownloadRepository _downloads;

  const DownloadSeasonUseCase({
    required SeriesRepository series,
    required DownloadRepository downloads,
  }) : _series = series,
       _downloads = downloads;

  Stream<DownloadSeasonProgress> execute({
    required String seriesId,
    required int seasonNumber,
  }) {
    final controller = StreamController<DownloadSeasonProgress>();
    var cancelled = false;
    String? activeEpisodeId;
    StreamSubscription<EpisodeDownload>? activeSub;

    controller.onCancel = () async {
      cancelled = true;
      await activeSub?.cancel();
      if (activeEpisodeId != null) {
        await _downloads.cancelEpisode(activeEpisodeId!);
      }
    };

    Future<void> run() async {
      try {
        final series = await _series.findById(seriesId);
        final season = series.seasons.firstWhere(
          (s) => s.seasonNumber == seasonNumber,
          orElse: () => throw StateError(
            'Season $seasonNumber not found in series $seriesId',
          ),
        );
        final episodes = [...season.episodes]
          ..sort((a, b) => a.episodeNumber.compareTo(b.episodeNumber));
        final total = episodes.length;
        var done = 0;

        for (final Episode ep in episodes) {
          if (cancelled) break;
          activeEpisodeId = ep.id;

          final terminal = await _runOneEpisode(
            episode: ep,
            total: total,
            done: done,
            controller: controller,
            attachSub: (s) => activeSub = s,
          );

          activeSub = null;
          activeEpisodeId = null;

          if (terminal == DownloadStatus.failed) {
            // Stop the loop on a true failure.
            break;
          }
          if (terminal == DownloadStatus.cancelled) {
            break;
          }
          if (terminal == DownloadStatus.complete) {
            await _downloads.setEpisodeKind(ep.id, DownloadKind.download);
            done++;
          }
        }
      } catch (e, st) {
        controller.addError(e, st);
      } finally {
        if (!controller.isClosed) await controller.close();
      }
    }

    unawaited(run());
    return controller.stream;
  }

  /// Runs one episode's download to its terminal status and returns it.
  /// Wires the live snapshots into [controller] as
  /// [DownloadSeasonProgress] updates.
  Future<DownloadStatus> _runOneEpisode({
    required Episode episode,
    required int total,
    required int done,
    required StreamController<DownloadSeasonProgress> controller,
    required void Function(StreamSubscription<EpisodeDownload>) attachSub,
  }) async {
    final completer = Completer<DownloadStatus>();

    final stream = _downloads.downloadEpisode(episode.id);
    final sub = stream.listen(
      (snapshot) {
        if (controller.isClosed) return;
        controller.add(
          DownloadSeasonProgress(
            totalEpisodes: total,
            doneEpisodes: done,
            currentEpisodeId: episode.id,
            currentSnapshot: snapshot,
          ),
        );
        if (snapshot.status == DownloadStatus.complete ||
            snapshot.status == DownloadStatus.failed ||
            snapshot.status == DownloadStatus.cancelled) {
          if (!completer.isCompleted) completer.complete(snapshot.status);
        }
      },
      onError: (e, st) {
        if (!completer.isCompleted) completer.complete(DownloadStatus.failed);
      },
      onDone: () {
        if (!completer.isCompleted) completer.complete(DownloadStatus.complete);
      },
    );
    attachSub(sub);

    final result = await completer.future;
    await sub.cancel();
    return result;
  }
}
