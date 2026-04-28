// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'watch_progress.repository_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Watch-progress repository provider.
///
/// Selects between two implementations based on the compile-time constant
/// `String.fromEnvironment('API_BASE_URL')`:
///
/// - **empty (default)** → [InMemoryWatchProgressRepository] — used by
///   tests, by `flutter run` without flag, and by anyone running
///   offline. Stores progress in a `Map` reset at every app restart.
/// - **non-empty** → [DioWatchProgressRepository] consuming [dioProvider]
///   — hits the three watch-progress endpoints documented in `API.md`
///   § Progression de lecture, with `Authorization: Bearer <jwt>` and
///   `X-Device-Id` headers injected transparently by the
///   `AuthInterceptor`. Used by
///   `flutter run --dart-define=API_BASE_URL=http://localhost:8080`.
///
/// Switching modes requires a full rebuild — `String.fromEnvironment` is
/// evaluated at compile time, not at runtime.

@ProviderFor(watchProgressRepository)
final watchProgressRepositoryProvider = WatchProgressRepositoryProvider._();

/// Watch-progress repository provider.
///
/// Selects between two implementations based on the compile-time constant
/// `String.fromEnvironment('API_BASE_URL')`:
///
/// - **empty (default)** → [InMemoryWatchProgressRepository] — used by
///   tests, by `flutter run` without flag, and by anyone running
///   offline. Stores progress in a `Map` reset at every app restart.
/// - **non-empty** → [DioWatchProgressRepository] consuming [dioProvider]
///   — hits the three watch-progress endpoints documented in `API.md`
///   § Progression de lecture, with `Authorization: Bearer <jwt>` and
///   `X-Device-Id` headers injected transparently by the
///   `AuthInterceptor`. Used by
///   `flutter run --dart-define=API_BASE_URL=http://localhost:8080`.
///
/// Switching modes requires a full rebuild — `String.fromEnvironment` is
/// evaluated at compile time, not at runtime.

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
  /// Selects between two implementations based on the compile-time constant
  /// `String.fromEnvironment('API_BASE_URL')`:
  ///
  /// - **empty (default)** → [InMemoryWatchProgressRepository] — used by
  ///   tests, by `flutter run` without flag, and by anyone running
  ///   offline. Stores progress in a `Map` reset at every app restart.
  /// - **non-empty** → [DioWatchProgressRepository] consuming [dioProvider]
  ///   — hits the three watch-progress endpoints documented in `API.md`
  ///   § Progression de lecture, with `Authorization: Bearer <jwt>` and
  ///   `X-Device-Id` headers injected transparently by the
  ///   `AuthInterceptor`. Used by
  ///   `flutter run --dart-define=API_BASE_URL=http://localhost:8080`.
  ///
  /// Switching modes requires a full rebuild — `String.fromEnvironment` is
  /// evaluated at compile time, not at runtime.
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
    r'a85c228a4e2502d510d46c48f02604cc700f58ce';
