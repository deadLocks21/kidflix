import 'dart:io';

import 'package:kidflix/core/domain/services/watch_progress.repository.dart';
import 'package:kidflix/infrastructure/providers/api_base_url.provider.dart';
import 'package:kidflix/infrastructure/providers/connectivity.service_provider.dart';
import 'package:kidflix/infrastructure/providers/dio.provider.dart';
import 'package:kidflix/infrastructure/watch_progress/dio.watch_progress.repository.dart';
import 'package:kidflix/infrastructure/watch_progress/in_memory.watch_progress.repository.dart';
import 'package:kidflix/infrastructure/watch_progress/offline_first.watch_progress.repository.dart';
import 'package:kidflix/infrastructure/watch_progress/watch_progress_disk_store.dart';
import 'package:kidflix/infrastructure/watch_progress/watch_progress_pending_queue.dart';
import 'package:kidflix/infrastructure/watch_progress/watch_progress_sync.service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'watch_progress.repository_provider.g.dart';

Future<Directory> _resolveDocsDir() => getApplicationDocumentsDirectory();

/// Disk-backed mirror of every [WatchProgress] known to the client.
/// Persists at `<appDocs>/watch_progress.json` so progressions survive
/// app restarts even before the backend roundtrip (cf. offline-first
/// design).
@Riverpod(keepAlive: true)
WatchProgressDiskStore watchProgressDiskStore(Ref ref) {
  return JsonFileWatchProgressStore(resolveDir: _resolveDocsDir);
}

/// Persistent FIFO queue of writes deferred until connectivity returns.
@Riverpod(keepAlive: true)
WatchProgressPendingQueue watchProgressPendingQueue(Ref ref) {
  return JsonFileWatchProgressPendingQueue(resolveDir: _resolveDocsDir);
}

/// Watch-progress repository provider.
///
/// Always returns an [OfflineFirstWatchProgressRepository] wrapping the
/// platform-appropriate remote implementation:
///
/// - **empty / demo URL** → wraps [InMemoryWatchProgressRepository] (no
///   real backend ; the decorator still routes reads through disk so
///   progressions survive restarts).
/// - **real URL** → wraps [DioWatchProgressRepository], which hits the
///   `/profiles/{p}/progress/*` endpoints documented in `API.md`.
///
/// Reads always come from the disk store. Writes go to disk first, then
/// to the remote (skipped offline, queued on failure). The
/// [watchProgressSyncServiceProvider] drains the queue on reconnect.
@Riverpod(keepAlive: true)
WatchProgressRepository watchProgressRepository(Ref ref) {
  final baseUrl = ref.watch(apiBaseUrlProvider);
  final WatchProgressRepository remote = isInMemoryBaseUrl(baseUrl)
      ? InMemoryWatchProgressRepository()
      : DioWatchProgressRepository(dio: ref.watch(dioProvider));
  return OfflineFirstWatchProgressRepository(
    remote: remote,
    store: ref.watch(watchProgressDiskStoreProvider),
    queue: ref.watch(watchProgressPendingQueueProvider),
    connectivity: ref.watch(connectivityServiceProvider),
  );
}

/// Background sync service that drains the queue on reconnect.
/// Started by the bootstrap flow ; lifecycle is tied to the provider's
/// container.
@Riverpod(keepAlive: true)
WatchProgressSyncService watchProgressSyncService(Ref ref) {
  final baseUrl = ref.watch(apiBaseUrlProvider);
  final WatchProgressRepository remote = isInMemoryBaseUrl(baseUrl)
      ? InMemoryWatchProgressRepository()
      : DioWatchProgressRepository(dio: ref.watch(dioProvider));
  final service = WatchProgressSyncService(
    remote: remote,
    queue: ref.watch(watchProgressPendingQueueProvider),
    connectivity: ref.watch(connectivityServiceProvider),
  );
  ref.onDispose(service.dispose);
  return service;
}
