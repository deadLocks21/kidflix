// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'watch_progress.repository_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Watch-progress repository provider.
///
/// Currently always returns [InMemoryWatchProgressRepository]. Will be
/// replaced by an HTTP variant when the backend is available.

@ProviderFor(watchProgressRepository)
final watchProgressRepositoryProvider = WatchProgressRepositoryProvider._();

/// Watch-progress repository provider.
///
/// Currently always returns [InMemoryWatchProgressRepository]. Will be
/// replaced by an HTTP variant when the backend is available.

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
  /// Currently always returns [InMemoryWatchProgressRepository]. Will be
  /// replaced by an HTTP variant when the backend is available.
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
    r'341eaf49d62d5adbbcd4bd700ea7c7dd9ac768be';
