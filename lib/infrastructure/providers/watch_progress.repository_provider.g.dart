// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'watch_progress.repository_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Watch-progress repository provider.
///
/// Selects between two implementations based on [apiBaseUrlProvider]:
///
/// - **empty** → [InMemoryWatchProgressRepository] — used by tests and
///   when no backend has been configured. Stores progress in a `Map`
///   reset at every app restart.
/// - **non-empty** → [DioWatchProgressRepository] consuming [dioProvider]
///   — hits the three watch-progress endpoints documented in `API.md`
///   § Progression de lecture, with `Authorization: Bearer <jwt>` and
///   `X-Device-Id` headers injected transparently by the
///   `AuthInterceptor`. The URL is configured by the user via the ⚙
///   dialog on the phone-entry page.

@ProviderFor(watchProgressRepository)
final watchProgressRepositoryProvider = WatchProgressRepositoryProvider._();

/// Watch-progress repository provider.
///
/// Selects between two implementations based on [apiBaseUrlProvider]:
///
/// - **empty** → [InMemoryWatchProgressRepository] — used by tests and
///   when no backend has been configured. Stores progress in a `Map`
///   reset at every app restart.
/// - **non-empty** → [DioWatchProgressRepository] consuming [dioProvider]
///   — hits the three watch-progress endpoints documented in `API.md`
///   § Progression de lecture, with `Authorization: Bearer <jwt>` and
///   `X-Device-Id` headers injected transparently by the
///   `AuthInterceptor`. The URL is configured by the user via the ⚙
///   dialog on the phone-entry page.

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
  /// Selects between two implementations based on [apiBaseUrlProvider]:
  ///
  /// - **empty** → [InMemoryWatchProgressRepository] — used by tests and
  ///   when no backend has been configured. Stores progress in a `Map`
  ///   reset at every app restart.
  /// - **non-empty** → [DioWatchProgressRepository] consuming [dioProvider]
  ///   — hits the three watch-progress endpoints documented in `API.md`
  ///   § Progression de lecture, with `Authorization: Bearer <jwt>` and
  ///   `X-Device-Id` headers injected transparently by the
  ///   `AuthInterceptor`. The URL is configured by the user via the ⚙
  ///   dialog on the phone-entry page.
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
    r'e5985531d10187724604048c1a25c65403624740';
