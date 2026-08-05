// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'remote_playback_host.controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The application-side half of remote control on the *host* device.
///
/// Holds the state remotes see, and owns the only reference to the
/// mounted player's [PlaybackRemoteControls]. Everything above it (the
/// HTTP server) stays free of Flutter; everything below it (the player
/// page) stays free of networking.

@ProviderFor(RemotePlaybackHost)
final remotePlaybackHostProvider = RemotePlaybackHostProvider._();

/// The application-side half of remote control on the *host* device.
///
/// Holds the state remotes see, and owns the only reference to the
/// mounted player's [PlaybackRemoteControls]. Everything above it (the
/// HTTP server) stays free of Flutter; everything below it (the player
/// page) stays free of networking.
final class RemotePlaybackHostProvider
    extends $NotifierProvider<RemotePlaybackHost, RemotePlaybackState> {
  /// The application-side half of remote control on the *host* device.
  ///
  /// Holds the state remotes see, and owns the only reference to the
  /// mounted player's [PlaybackRemoteControls]. Everything above it (the
  /// HTTP server) stays free of Flutter; everything below it (the player
  /// page) stays free of networking.
  RemotePlaybackHostProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'remotePlaybackHostProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$remotePlaybackHostHash();

  @$internal
  @override
  RemotePlaybackHost create() => RemotePlaybackHost();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(RemotePlaybackState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<RemotePlaybackState>(value),
    );
  }
}

String _$remotePlaybackHostHash() =>
    r'b74b0316bb7bc37f39870333f0feb41260620c3b';

/// The application-side half of remote control on the *host* device.
///
/// Holds the state remotes see, and owns the only reference to the
/// mounted player's [PlaybackRemoteControls]. Everything above it (the
/// HTTP server) stays free of Flutter; everything below it (the player
/// page) stays free of networking.

abstract class _$RemotePlaybackHost extends $Notifier<RemotePlaybackState> {
  RemotePlaybackState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<RemotePlaybackState, RemotePlaybackState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<RemotePlaybackState, RemotePlaybackState>,
              RemotePlaybackState,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}

/// Owns the lifecycle of the local control server and wires it to
/// [RemotePlaybackHost].
///
/// State is "is remote control accepted on this device", persisted so the
/// setting survives a restart — a device parked next to the TV should not
/// need re-enabling every launch.

@ProviderFor(RemoteHostController)
final remoteHostControllerProvider = RemoteHostControllerProvider._();

/// Owns the lifecycle of the local control server and wires it to
/// [RemotePlaybackHost].
///
/// State is "is remote control accepted on this device", persisted so the
/// setting survives a restart — a device parked next to the TV should not
/// need re-enabling every launch.
final class RemoteHostControllerProvider
    extends $NotifierProvider<RemoteHostController, bool> {
  /// Owns the lifecycle of the local control server and wires it to
  /// [RemotePlaybackHost].
  ///
  /// State is "is remote control accepted on this device", persisted so the
  /// setting survives a restart — a device parked next to the TV should not
  /// need re-enabling every launch.
  RemoteHostControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'remoteHostControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$remoteHostControllerHash();

  @$internal
  @override
  RemoteHostController create() => RemoteHostController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$remoteHostControllerHash() =>
    r'f2832e757118547d56283e57d7c1d1e90858ebe8';

/// Owns the lifecycle of the local control server and wires it to
/// [RemotePlaybackHost].
///
/// State is "is remote control accepted on this device", persisted so the
/// setting survives a restart — a device parked next to the TV should not
/// need re-enabling every launch.

abstract class _$RemoteHostController extends $Notifier<bool> {
  bool build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<bool, bool>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<bool, bool>,
              bool,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
