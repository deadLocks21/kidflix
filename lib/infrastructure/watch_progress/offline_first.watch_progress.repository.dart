import 'dart:async';
import 'dart:developer' as developer;

import 'package:kidflix/core/domain/model/watch_progress.dart';
import 'package:kidflix/core/domain/services/connectivity.service.dart';
import 'package:kidflix/core/domain/services/watch_progress.repository.dart';
import 'package:kidflix/infrastructure/watch_progress/watch_progress_disk_store.dart';
import 'package:kidflix/infrastructure/watch_progress/watch_progress_pending_queue.dart';

/// [WatchProgressRepository] decorator implementing the offline-first
/// contract on top of a remote repository, a disk store and a pending
/// queue.
///
/// Read side: every `findFor*` / `listForProfile` goes to the disk
/// store. The remote is never consulted on the read path — that keeps
/// the UI instant and snappy regardless of connectivity. The sync
/// service (`WatchProgressSyncService`) is responsible for keeping the
/// disk in sync with the remote in the background.
///
/// Write side: every mutation (`save`, `dismiss*`, `unDismiss*`) writes
/// to disk first so the UI sees it immediately on subsequent reads.
/// Then:
///
/// * **online** → the remote is called inline. On success the queue is
///   left untouched (no need to replay). On failure (or when the device
///   reports offline mid-flight) the operation is appended to the queue
///   so the sync service can replay it.
/// * **offline** → the remote is skipped entirely and the operation is
///   queued.
///
/// The queue uses last-write-wins per `(key, opKind)` to avoid
/// unbounded growth: rapid successive saves on the same media collapse
/// to the most recent state.
class OfflineFirstWatchProgressRepository implements WatchProgressRepository {
  final WatchProgressRepository _remote;
  final WatchProgressDiskStore _store;
  final WatchProgressPendingQueue _queue;
  final ConnectivityService _connectivity;

  OfflineFirstWatchProgressRepository({
    required WatchProgressRepository remote,
    required WatchProgressDiskStore store,
    required WatchProgressPendingQueue queue,
    required ConnectivityService connectivity,
  })  : _remote = remote,
        _store = store,
        _queue = queue,
        _connectivity = connectivity;

  @override
  Future<MovieProgress?> findForMovie({
    required String profileId,
    required String movieId,
  }) async {
    final progress = await _store.find(
      isEpisode: false,
      profileId: profileId,
      mediaId: movieId,
    );
    if (progress is MovieProgress) return progress;
    return null;
  }

  @override
  Future<EpisodeProgress?> findForEpisode({
    required String profileId,
    required String episodeId,
  }) async {
    final progress = await _store.find(
      isEpisode: true,
      profileId: profileId,
      mediaId: episodeId,
    );
    if (progress is EpisodeProgress) return progress;
    return null;
  }

  @override
  Future<List<WatchProgress>> listForProfile(String profileId) {
    return _store.listForProfile(profileId);
  }

  @override
  Future<void> save(WatchProgress progress) async {
    await _store.save(progress);
    final op = PendingProgressOp(
      kind: PendingProgressOpKind.save,
      isEpisode: progress is EpisodeProgress,
      profileId: progress.profileId,
      mediaId: switch (progress) {
        MovieProgress(:final movieId) => movieId,
        EpisodeProgress(:final episodeId) => episodeId,
      },
      progress: progress,
    );
    await _tryReplayThenQueue(op, () => _remote.save(progress));
  }

  @override
  Future<void> dismissMovie({
    required String profileId,
    required String movieId,
  }) async {
    await _store.setDismissed(
      isEpisode: false,
      profileId: profileId,
      mediaId: movieId,
      dismissed: true,
    );
    final op = PendingProgressOp(
      kind: PendingProgressOpKind.dismiss,
      isEpisode: false,
      profileId: profileId,
      mediaId: movieId,
    );
    await _tryReplayThenQueue(
      op,
      () => _remote.dismissMovie(profileId: profileId, movieId: movieId),
    );
  }

  @override
  Future<void> unDismissMovie({
    required String profileId,
    required String movieId,
  }) async {
    await _store.setDismissed(
      isEpisode: false,
      profileId: profileId,
      mediaId: movieId,
      dismissed: false,
    );
    final op = PendingProgressOp(
      kind: PendingProgressOpKind.undismiss,
      isEpisode: false,
      profileId: profileId,
      mediaId: movieId,
    );
    await _tryReplayThenQueue(
      op,
      () => _remote.unDismissMovie(profileId: profileId, movieId: movieId),
    );
  }

  @override
  Future<void> dismissEpisode({
    required String profileId,
    required String episodeId,
  }) async {
    await _store.setDismissed(
      isEpisode: true,
      profileId: profileId,
      mediaId: episodeId,
      dismissed: true,
    );
    final op = PendingProgressOp(
      kind: PendingProgressOpKind.dismiss,
      isEpisode: true,
      profileId: profileId,
      mediaId: episodeId,
    );
    await _tryReplayThenQueue(
      op,
      () => _remote.dismissEpisode(profileId: profileId, episodeId: episodeId),
    );
  }

  @override
  Future<void> unDismissEpisode({
    required String profileId,
    required String episodeId,
  }) async {
    await _store.setDismissed(
      isEpisode: true,
      profileId: profileId,
      mediaId: episodeId,
      dismissed: false,
    );
    final op = PendingProgressOp(
      kind: PendingProgressOpKind.undismiss,
      isEpisode: true,
      profileId: profileId,
      mediaId: episodeId,
    );
    await _tryReplayThenQueue(
      op,
      () => _remote.unDismissEpisode(
        profileId: profileId,
        episodeId: episodeId,
      ),
    );
  }

  /// Common write path: when online, attempt the remote call ; on
  /// success drop any previously-queued op for the same `(key, kind)` ;
  /// on failure enqueue. When offline, enqueue without touching the
  /// remote.
  Future<void> _tryReplayThenQueue(
    PendingProgressOp op,
    Future<void> Function() remoteCall,
  ) async {
    if (!_connectivity.isOnline) {
      await _queue.enqueue(op);
      return;
    }
    try {
      await remoteCall();
      // Drop any previously-queued op for this key+kind — the remote
      // is now caught up.
      await _queue.remove(op);
    } catch (e) {
      developer.log(
        'remote watch-progress write failed — queued for retry',
        name: 'kidflix.watch_progress.offline_first',
        level: 800,
        error: e,
      );
      await _queue.enqueue(op);
    }
  }
}
