// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'watch_progress.repository_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Disk-backed mirror of every [WatchProgress] known to the client.
/// Persists at `<appDocs>/watch_progress.json` so progressions survive
/// app restarts even before the backend roundtrip (cf. offline-first
/// design).

@ProviderFor(watchProgressDiskStore)
final watchProgressDiskStoreProvider = WatchProgressDiskStoreProvider._();

/// Disk-backed mirror of every [WatchProgress] known to the client.
/// Persists at `<appDocs>/watch_progress.json` so progressions survive
/// app restarts even before the backend roundtrip (cf. offline-first
/// design).

final class WatchProgressDiskStoreProvider
    extends
        $FunctionalProvider<
          WatchProgressDiskStore,
          WatchProgressDiskStore,
          WatchProgressDiskStore
        >
    with $Provider<WatchProgressDiskStore> {
  /// Disk-backed mirror of every [WatchProgress] known to the client.
  /// Persists at `<appDocs>/watch_progress.json` so progressions survive
  /// app restarts even before the backend roundtrip (cf. offline-first
  /// design).
  WatchProgressDiskStoreProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'watchProgressDiskStoreProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$watchProgressDiskStoreHash();

  @$internal
  @override
  $ProviderElement<WatchProgressDiskStore> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  WatchProgressDiskStore create(Ref ref) {
    return watchProgressDiskStore(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(WatchProgressDiskStore value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<WatchProgressDiskStore>(value),
    );
  }
}

String _$watchProgressDiskStoreHash() =>
    r'adc8cd59affc2d4d7d206f8b7da07af4287e66ea';

/// Persistent FIFO queue of writes deferred until connectivity returns.

@ProviderFor(watchProgressPendingQueue)
final watchProgressPendingQueueProvider = WatchProgressPendingQueueProvider._();

/// Persistent FIFO queue of writes deferred until connectivity returns.

final class WatchProgressPendingQueueProvider
    extends
        $FunctionalProvider<
          WatchProgressPendingQueue,
          WatchProgressPendingQueue,
          WatchProgressPendingQueue
        >
    with $Provider<WatchProgressPendingQueue> {
  /// Persistent FIFO queue of writes deferred until connectivity returns.
  WatchProgressPendingQueueProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'watchProgressPendingQueueProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$watchProgressPendingQueueHash();

  @$internal
  @override
  $ProviderElement<WatchProgressPendingQueue> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  WatchProgressPendingQueue create(Ref ref) {
    return watchProgressPendingQueue(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(WatchProgressPendingQueue value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<WatchProgressPendingQueue>(value),
    );
  }
}

String _$watchProgressPendingQueueHash() =>
    r'b25aad4c045be2d94b3ffabe4949520845d4e7e6';

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

@ProviderFor(watchProgressRepository)
final watchProgressRepositoryProvider = WatchProgressRepositoryProvider._();

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

final class WatchProgressRepositoryProvider
    extends
        $FunctionalProvider<
          WatchProgressRepository,
          WatchProgressRepository,
          WatchProgressRepository
        >
    with $Provider<WatchProgressRepository> {
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
  WatchProgressRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'watchProgressRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$watchProgressRepositoryHash();

  @$internal
  @override
  $ProviderElement<WatchProgressRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  WatchProgressRepository create(Ref ref) {
    return watchProgressRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(WatchProgressRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<WatchProgressRepository>(value),
    );
  }
}

String _$watchProgressRepositoryHash() =>
    r'90ce648634d8eb97a706f0bf256541f5e7b2bce2';

/// Background sync service that drains the queue on reconnect.
/// Started by the bootstrap flow ; lifecycle is tied to the provider's
/// container.

@ProviderFor(watchProgressSyncService)
final watchProgressSyncServiceProvider = WatchProgressSyncServiceProvider._();

/// Background sync service that drains the queue on reconnect.
/// Started by the bootstrap flow ; lifecycle is tied to the provider's
/// container.

final class WatchProgressSyncServiceProvider
    extends
        $FunctionalProvider<
          WatchProgressSyncService,
          WatchProgressSyncService,
          WatchProgressSyncService
        >
    with $Provider<WatchProgressSyncService> {
  /// Background sync service that drains the queue on reconnect.
  /// Started by the bootstrap flow ; lifecycle is tied to the provider's
  /// container.
  WatchProgressSyncServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'watchProgressSyncServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$watchProgressSyncServiceHash();

  @$internal
  @override
  $ProviderElement<WatchProgressSyncService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  WatchProgressSyncService create(Ref ref) {
    return watchProgressSyncService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(WatchProgressSyncService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<WatchProgressSyncService>(value),
    );
  }
}

String _$watchProgressSyncServiceHash() =>
    r'0136e866a3e8f603604024b72ade2a7a615e5363';
