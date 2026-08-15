import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kidflix/core/domain/model/watch_progress.dart';
import 'package:kidflix/core/domain/services/connectivity.service.dart';
import 'package:kidflix/core/domain/services/watch_progress.repository.dart';
import 'package:kidflix/infrastructure/watch_progress/watch_progress_disk_store.dart';
import 'package:kidflix/infrastructure/watch_progress/watch_progress_pending_queue.dart';
import 'package:kidflix/infrastructure/watch_progress/watch_progress_sync.service.dart';

class _FakeConnectivity implements ConnectivityService {
  _FakeConnectivity({this.online = true});
  bool online;
  @override
  bool get isOnline => online;
  @override
  Stream<bool> watch() => const Stream<bool>.empty();
}

class _NoopQueue implements WatchProgressPendingQueue {
  @override
  Future<void> enqueue(PendingProgressOp op) async {}
  @override
  Future<List<PendingProgressOp>> readAll() async => const [];
  @override
  Future<void> remove(PendingProgressOp op) async {}
  @override
  Future<void> clear() async {}
}

class _MemStore implements WatchProgressDiskStore {
  _MemStore(this.entries);
  List<WatchProgress> entries;
  int replaceCalls = 0;

  @override
  Future<List<WatchProgress>> listForProfile(String profileId) async =>
      entries.where((e) => e.profileId == profileId).toList();

  @override
  Future<void> replaceProfile(
    String profileId,
    List<WatchProgress> progresses,
  ) async {
    replaceCalls++;
    entries = [
      ...entries.where((e) => e.profileId != profileId),
      ...progresses,
    ];
  }

  @override
  Future<WatchProgress?> find({
    required bool isEpisode,
    required String profileId,
    required String mediaId,
  }) async => null;
  @override
  Future<void> save(WatchProgress progress) async {}
  @override
  Future<void> setDismissed({
    required bool isEpisode,
    required String profileId,
    required String mediaId,
    required bool dismissed,
  }) async {}
}

class _FakeRemote implements WatchProgressRepository {
  _FakeRemote(this._byProfile);
  final Map<String, List<WatchProgress>> _byProfile;
  final List<String> listCalls = [];
  Object? throwOnList;

  @override
  Future<List<WatchProgress>> listForProfile(String profileId) async {
    listCalls.add(profileId);
    if (throwOnList != null) throw throwOnList!;
    return _byProfile[profileId] ?? const [];
  }

  @override
  Future<MovieProgress?> findForMovie({
    required String profileId,
    required String movieId,
  }) async => null;
  @override
  Future<EpisodeProgress?> findForEpisode({
    required String profileId,
    required String episodeId,
  }) async => null;
  @override
  Future<void> save(WatchProgress progress) async {}
  @override
  Future<void> dismissMovie({
    required String profileId,
    required String movieId,
  }) async {}
  @override
  Future<void> unDismissMovie({
    required String profileId,
    required String movieId,
  }) async {}
  @override
  Future<void> dismissEpisode({
    required String profileId,
    required String episodeId,
  }) async {}
  @override
  Future<void> unDismissEpisode({
    required String profileId,
    required String episodeId,
  }) async {}
}

EpisodeProgress _ep({
  String profileId = 'p1',
  required String episodeId,
  String? seriesId,
  int positionSeconds = 120,
  bool completed = false,
  bool dismissed = false,
  DateTime? updatedAt,
}) => EpisodeProgress(
  profileId: profileId,
  episodeId: episodeId,
  seriesId: seriesId,
  positionSeconds: positionSeconds,
  completed: completed,
  dismissed: dismissed,
  updatedAt: updatedAt ?? DateTime.utc(2026, 5, 4),
);

({WatchProgressSyncService service, _MemStore store, _FakeRemote remote})
build({
  required List<WatchProgress> local,
  required Map<String, List<WatchProgress>> remote,
  bool online = true,
}) {
  final store = _MemStore([...local]);
  final fakeRemote = _FakeRemote(remote);
  return (
    service: WatchProgressSyncService(
      remote: fakeRemote,
      store: store,
      queue: _NoopQueue(),
      connectivity: _FakeConnectivity(online: online),
    ),
    store: store,
    remote: fakeRemote,
  );
}

void main() {
  group('WatchProgressSyncService.backfillSeriesIds', () {
    test('stamps the parent series onto entries that lack it', () async {
      final ctx = build(
        local: [_ep(episodeId: 'e1')],
        remote: {
          'p1': [_ep(episodeId: 'e1', seriesId: 'pingu')],
        },
      );

      await ctx.service.backfillSeriesIds(['p1']);

      final stored = ctx.store.entries.single as EpisodeProgress;
      expect(stored.seriesId, 'pingu');
    });

    test('never overwrites local playback state', () async {
      final ctx = build(
        local: [
          _ep(
            episodeId: 'e1',
            positionSeconds: 900,
            completed: false,
            dismissed: true,
            updatedAt: DateTime.utc(2026, 6, 1),
          ),
        ],
        remote: {
          'p1': [
            // Stale server values — a pending local write has not landed
            // yet. Only series_id may be taken from this.
            _ep(
              episodeId: 'e1',
              seriesId: 'pingu',
              positionSeconds: 10,
              completed: true,
              dismissed: false,
              updatedAt: DateTime.utc(2026, 1, 1),
            ),
          ],
        },
      );

      await ctx.service.backfillSeriesIds(['p1']);

      final stored = ctx.store.entries.single as EpisodeProgress;
      expect(stored.seriesId, 'pingu');
      expect(stored.positionSeconds, 900);
      expect(stored.completed, isFalse);
      expect(stored.dismissed, isTrue);
      expect(stored.updatedAt, DateTime.utc(2026, 6, 1));
    });

    test('does not hit the remote when nothing is missing', () async {
      final ctx = build(
        local: [_ep(episodeId: 'e1', seriesId: 'pingu')],
        remote: {
          'p1': [_ep(episodeId: 'e1', seriesId: 'pingu')],
        },
      );

      await ctx.service.backfillSeriesIds(['p1']);

      expect(ctx.remote.listCalls, isEmpty);
      expect(ctx.store.replaceCalls, 0);
    });

    test('one request per profile, deduplicated', () async {
      final ctx = build(
        local: [
          _ep(episodeId: 'e1'),
          _ep(profileId: 'p2', episodeId: 'e2'),
        ],
        remote: {
          'p1': [_ep(episodeId: 'e1', seriesId: 'pingu')],
          'p2': [_ep(profileId: 'p2', episodeId: 'e2', seriesId: 'trotro')],
        },
      );

      await ctx.service.backfillSeriesIds(['p1', 'p2', 'p1']);

      expect(ctx.remote.listCalls, ['p1', 'p2']);
    });

    test('leaves movie entries untouched', () async {
      final movie = MovieProgress(
        profileId: 'p1',
        movieId: 'nemo',
        positionSeconds: 300,
        completed: false,
        updatedAt: DateTime.utc(2026, 5, 4),
      );
      final ctx = build(
        local: [
          movie,
          _ep(episodeId: 'e1'),
        ],
        remote: {
          'p1': [_ep(episodeId: 'e1', seriesId: 'pingu')],
        },
      );

      await ctx.service.backfillSeriesIds(['p1']);

      expect(ctx.store.entries.whereType<MovieProgress>().single, movie);
    });

    test('an episode the remote cannot resolve is left as-is', () async {
      final ctx = build(
        local: [
          _ep(episodeId: 'e1'),
          _ep(episodeId: 'orphan'),
        ],
        remote: {
          'p1': [_ep(episodeId: 'e1', seriesId: 'pingu')],
        },
      );

      await ctx.service.backfillSeriesIds(['p1']);

      final byId = {
        for (final e in ctx.store.entries.whereType<EpisodeProgress>())
          e.episodeId: e.seriesId,
      };
      expect(byId, {'e1': 'pingu', 'orphan': null});
    });

    test('a failing profile does not abort the others', () async {
      final ctx = build(
        local: [_ep(episodeId: 'e1')],
        remote: {
          'p1': [_ep(episodeId: 'e1', seriesId: 'pingu')],
        },
      );
      ctx.remote.throwOnList = StateError('progress endpoint down');

      // Best-effort: swallowed, and the entry keeps its null seriesId so
      // Continue Watching falls back rather than losing the row.
      await ctx.service.backfillSeriesIds(['p1']);

      final stored = ctx.store.entries.single as EpisodeProgress;
      expect(stored.seriesId, isNull);
    });

    test('offline is a no-op', () async {
      final ctx = build(
        local: [_ep(episodeId: 'e1')],
        remote: {
          'p1': [_ep(episodeId: 'e1', seriesId: 'pingu')],
        },
        online: false,
      );

      await ctx.service.backfillSeriesIds(['p1']);

      expect(ctx.remote.listCalls, isEmpty);
    });
  });
}
