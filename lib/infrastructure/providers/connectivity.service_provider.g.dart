// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'connectivity.service_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Single app-wide [ConnectivityService] instance. `keepAlive` because
/// the underlying platform subscription is expensive to spin up and the
/// service is consumed from many providers (catalog source switching,
/// watch progress sync, offline banner, …).

@ProviderFor(connectivityService)
final connectivityServiceProvider = ConnectivityServiceProvider._();

/// Single app-wide [ConnectivityService] instance. `keepAlive` because
/// the underlying platform subscription is expensive to spin up and the
/// service is consumed from many providers (catalog source switching,
/// watch progress sync, offline banner, …).

final class ConnectivityServiceProvider
    extends
        $FunctionalProvider<
          ConnectivityService,
          ConnectivityService,
          ConnectivityService
        >
    with $Provider<ConnectivityService> {
  /// Single app-wide [ConnectivityService] instance. `keepAlive` because
  /// the underlying platform subscription is expensive to spin up and the
  /// service is consumed from many providers (catalog source switching,
  /// watch progress sync, offline banner, …).
  ConnectivityServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'connectivityServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$connectivityServiceHash();

  @$internal
  @override
  $ProviderElement<ConnectivityService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ConnectivityService create(Ref ref) {
    return connectivityService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ConnectivityService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ConnectivityService>(value),
    );
  }
}

String _$connectivityServiceHash() =>
    r'60cbc55cae7191052423078ea45f083c28d6e229';

/// Reactive online/offline boolean. Listeners rebuild on every
/// transition. Defaults to `true` until the platform reports a value
/// (cf. [ConnectivityPlusService] doc).

@ProviderFor(connectivity)
final connectivityProvider = ConnectivityProvider._();

/// Reactive online/offline boolean. Listeners rebuild on every
/// transition. Defaults to `true` until the platform reports a value
/// (cf. [ConnectivityPlusService] doc).

final class ConnectivityProvider
    extends $FunctionalProvider<AsyncValue<bool>, bool, Stream<bool>>
    with $FutureModifier<bool>, $StreamProvider<bool> {
  /// Reactive online/offline boolean. Listeners rebuild on every
  /// transition. Defaults to `true` until the platform reports a value
  /// (cf. [ConnectivityPlusService] doc).
  ConnectivityProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'connectivityProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$connectivityHash();

  @$internal
  @override
  $StreamProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<bool> create(Ref ref) {
    return connectivity(ref);
  }
}

String _$connectivityHash() => r'67f471db46a93e49be5a125767e524f1939f54ca';

/// Synchronous best-effort accessor for the latest known online state.
/// Reads the cached value from the underlying service so it never
/// suspends — useful in non-async paths (e.g. eager source selection
/// in another provider's `build`).

@ProviderFor(isOnline)
final isOnlineProvider = IsOnlineProvider._();

/// Synchronous best-effort accessor for the latest known online state.
/// Reads the cached value from the underlying service so it never
/// suspends — useful in non-async paths (e.g. eager source selection
/// in another provider's `build`).

final class IsOnlineProvider extends $FunctionalProvider<bool, bool, bool>
    with $Provider<bool> {
  /// Synchronous best-effort accessor for the latest known online state.
  /// Reads the cached value from the underlying service so it never
  /// suspends — useful in non-async paths (e.g. eager source selection
  /// in another provider's `build`).
  IsOnlineProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'isOnlineProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$isOnlineHash();

  @$internal
  @override
  $ProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  bool create(Ref ref) {
    return isOnline(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$isOnlineHash() => r'f435acd855277da01718ae5905a6e7a77d05dd1d';
