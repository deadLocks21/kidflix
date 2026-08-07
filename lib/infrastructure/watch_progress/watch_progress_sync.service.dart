import 'dart:async';
import 'dart:developer' as developer;

import 'package:kidflix/core/domain/model/watch_progress.dart';
import 'package:kidflix/core/domain/services/connectivity.service.dart';
import 'package:kidflix/core/domain/services/watch_progress.repository.dart';
import 'package:kidflix/infrastructure/watch_progress/watch_progress_disk_store.dart';
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
///
/// The service also owns the only remote→disk write in the app, and it
/// is deliberately narrow: [backfillSeriesIds] fills in the
/// [EpisodeProgress.seriesId] the disk store cannot know on its own.
/// Nothing else is pulled down — positions, completion and dismissals
/// remain local-authoritative, which is what the offline-first contract
/// promises. (A full remote→disk reconciliation is a separate concern:
/// progress recorded on another device is still not surfaced here.)
class WatchProgressSyncService {
  final WatchProgressRepository _remote;
  final WatchProgressDiskStore _store;
  final WatchProgressPendingQueue _queue;
  final ConnectivityService _connectivity;

  StreamSubscription<bool>? _subscription;
  final Lock _drainLock = Lock();
  final Lock _backfillLock = Lock();
  bool _disposed = false;

  WatchProgressSyncService({
    required WatchProgressRepository remote,
    required WatchProgressDiskStore store,
    required WatchProgressPendingQueue queue,
    required ConnectivityService connectivity,
  }) : _remote = remote,
       _store = store,
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

  /// Stamps the parent series onto local episode progresses that don't
  /// know it yet, using `series_id` from `GET /profiles/{p}/progress`.
  ///
  /// Why this exists: the disk store is written from local playback
  /// only, and the player does not always know the parent series. An
  /// entry saved that way — or saved by a build that predates
  /// `series_id` — sits on disk with a null `seriesId` forever, because
  /// nothing else ever writes to the store from the remote. Continue
  /// Watching then falls back to loading the whole catalog to find the
  /// parent of each episode, on **every** home load. In production that
  /// was one full catalog walk per home, indefinitely.
  ///
  /// One `GET /progress` per profile replaces all of it, once.
  ///
  /// Strictly additive: only a null `seriesId` is ever filled in, and
  /// only on entries that already exist locally. Position, completion,
  /// dismissal and `updatedAt` are read from disk and written back
  /// untouched — the remote is not authoritative for those, and a
  /// pending local write must not be clobbered by a stale server value.
  /// Silent and best-effort per profile: this is an optimisation, and
  /// the fallback still covers whatever it fails to resolve.
  Future<void> backfillSeriesIds(Iterable<String> profileIds) async {
    if (_disposed || !_connectivity.isOnline) return;
    final ids = profileIds.toSet();
    if (ids.isEmpty) return;
    await _backfillLock.synchronized(() async {
      for (final profileId in ids) {
        if (_disposed || !_connectivity.isOnline) return;
        try {
          await _backfillProfile(profileId);
        } catch (e) {
          developer.log(
            'series_id backfill failed for profile $profileId — '
            'Continue Watching keeps its fallback',
            name: 'kidflix.watch_progress.sync',
            level: 800,
            error: e,
          );
        }
      }
    });
  }

  Future<void> _backfillProfile(String profileId) async {
    final local = await _store.listForProfile(profileId);
    final missing = local
        .whereType<EpisodeProgress>()
        .where((p) => p.seriesId == null)
        .map((p) => p.episodeId)
        .toSet();
    if (missing.isEmpty) return;

    final remote = await _remote.listForProfile(profileId);
    final seriesByEpisode = <String, String>{
      for (final p in remote.whereType<EpisodeProgress>())
        p.episodeId: ?p.seriesId,
    };
    if (seriesByEpisode.isEmpty) return;

    var changed = false;
    final merged = <WatchProgress>[];
    for (final entry in local) {
      if (entry is EpisodeProgress && entry.seriesId == null) {
        final seriesId = seriesByEpisode[entry.episodeId];
        if (seriesId != null) {
          changed = true;
          merged.add(
            EpisodeProgress(
              profileId: entry.profileId,
              episodeId: entry.episodeId,
              seriesId: seriesId,
              positionSeconds: entry.positionSeconds,
              completed: entry.completed,
              dismissed: entry.dismissed,
              updatedAt: entry.updatedAt,
            ),
          );
          continue;
        }
      }
      merged.add(entry);
    }
    if (!changed) return;
    await _store.replaceProfile(profileId, merged);
  }

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
