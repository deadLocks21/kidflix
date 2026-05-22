import 'dart:async';
import 'dart:developer' as developer;

import 'package:kidflix/core/domain/services/connectivity.service.dart';
import 'package:kidflix/core/domain/services/watch_progress.repository.dart';
import 'package:kidflix/infrastructure/watch_progress/watch_progress_pending_queue.dart';
import 'package:synchronized/synchronized.dart';

/// Drains the [WatchProgressPendingQueue] into the remote
/// [WatchProgressRepository] whenever connectivity returns.
///
/// Listens to the connectivity stream and, on every offline→online
/// transition (plus once at startup if already online), iterates the
/// queue in FIFO order and replays each op. Successfully-replayed ops
/// are removed ; failing ops are left in the queue for the next try
/// so transient errors don't lose work.
///
/// Concurrency: a [Lock] guards `_drain` so overlapping triggers
/// (rapid online flicker, startup + change event) serialize cleanly.
class WatchProgressSyncService {
  final WatchProgressRepository _remote;
  final WatchProgressPendingQueue _queue;
  final ConnectivityService _connectivity;

  StreamSubscription<bool>? _subscription;
  final Lock _drainLock = Lock();
  bool _disposed = false;

  WatchProgressSyncService({
    required WatchProgressRepository remote,
    required WatchProgressPendingQueue queue,
    required ConnectivityService connectivity,
  }) : _remote = remote,
       _queue = queue,
       _connectivity = connectivity;

  /// Subscribes to the connectivity stream. Safe to call once at
  /// app startup. Subsequent calls are no-ops.
  void start() {
    if (_subscription != null || _disposed) return;
    _subscription = _connectivity.watch().listen((online) {
      if (online) unawaited(_drain());
    });
    if (_connectivity.isOnline) unawaited(_drain());
  }

  /// Triggers a drain immediately. Used by tests and by the offline-
  /// first repository's writer path when it wants to flush a freshly-
  /// queued op once the network call has just succeeded for a different
  /// item.
  Future<void> drainNow() => _drain();

  Future<void> _drain() async {
    if (_disposed) return;
    if (!_connectivity.isOnline) return;
    await _drainLock.synchronized(() async {
      final ops = await _queue.readAll();
      for (final op in ops) {
        if (!_connectivity.isOnline) break;
        try {
          await _replay(op);
          await _queue.remove(op);
        } catch (e) {
          developer.log(
            'replay of queued watch-progress op failed — leaving in queue',
            name: 'kidflix.watch_progress.sync',
            level: 800,
            error: e,
          );
          // Stop draining the queue on the first failure to preserve
          // FIFO semantics and avoid hammering the backend.
          break;
        }
      }
    });
  }

  Future<void> _replay(PendingProgressOp op) async {
    switch (op.kind) {
      case PendingProgressOpKind.save:
        final progress = op.progress;
        if (progress == null) return;
        await _remote.save(progress);
      case PendingProgressOpKind.dismiss:
        if (op.isEpisode) {
          await _remote.dismissEpisode(
            profileId: op.profileId,
            episodeId: op.mediaId,
          );
        } else {
          await _remote.dismissMovie(
            profileId: op.profileId,
            movieId: op.mediaId,
          );
        }
      case PendingProgressOpKind.undismiss:
        if (op.isEpisode) {
          await _remote.unDismissEpisode(
            profileId: op.profileId,
            episodeId: op.mediaId,
          );
        } else {
          await _remote.unDismissMovie(
            profileId: op.profileId,
            movieId: op.mediaId,
          );
        }
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    await _subscription?.cancel();
    _subscription = null;
  }
}
