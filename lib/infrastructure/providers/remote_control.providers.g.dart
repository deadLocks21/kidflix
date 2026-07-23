// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'remote_control.providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(remotePairingRepository)
final remotePairingRepositoryProvider = RemotePairingRepositoryProvider._();

final class RemotePairingRepositoryProvider
    extends
        $FunctionalProvider<
          RemotePairingRepository,
          RemotePairingRepository,
          RemotePairingRepository
        >
    with $Provider<RemotePairingRepository> {
  RemotePairingRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'remotePairingRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$remotePairingRepositoryHash();

  @$internal
  @override
  $ProviderElement<RemotePairingRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  RemotePairingRepository create(Ref ref) {
    return remotePairingRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(RemotePairingRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<RemotePairingRepository>(value),
    );
  }
}

String _$remotePairingRepositoryHash() =>
    r'2ddc65bb05d9f4d25436b4794eba2872c45442a0';

/// Stable id of this installation.
///
/// Synchronous on purpose. It used to be a `Future<String>` provider that
/// the host and discovery services read with `ref.watch(...).value` — but
/// that value is null until the future resolves, so both were built with
/// an **empty** device id and advertised `id=""` over mDNS. Remotes drop
/// an advertisement with no id (it is the key their pairing token is
/// stored under), so the device was never discoverable. Worse, when the
/// future did resolve, the `watch` rebuilt the host provider and disposed
/// the *running* server out from under the controller.
///
/// [RemoteBootstrap.load] fills it before anything reads it — the whole
/// UI is gated behind `bootstrapProvider`, so nothing can observe the
/// empty seed.

@ProviderFor(RemoteDeviceId)
final remoteDeviceIdProvider = RemoteDeviceIdProvider._();

/// Stable id of this installation.
///
/// Synchronous on purpose. It used to be a `Future<String>` provider that
/// the host and discovery services read with `ref.watch(...).value` — but
/// that value is null until the future resolves, so both were built with
/// an **empty** device id and advertised `id=""` over mDNS. Remotes drop
/// an advertisement with no id (it is the key their pairing token is
/// stored under), so the device was never discoverable. Worse, when the
/// future did resolve, the `watch` rebuilt the host provider and disposed
/// the *running* server out from under the controller.
///
/// [RemoteBootstrap.load] fills it before anything reads it — the whole
/// UI is gated behind `bootstrapProvider`, so nothing can observe the
/// empty seed.
final class RemoteDeviceIdProvider
    extends $NotifierProvider<RemoteDeviceId, String> {
  /// Stable id of this installation.
  ///
  /// Synchronous on purpose. It used to be a `Future<String>` provider that
  /// the host and discovery services read with `ref.watch(...).value` — but
  /// that value is null until the future resolves, so both were built with
  /// an **empty** device id and advertised `id=""` over mDNS. Remotes drop
  /// an advertisement with no id (it is the key their pairing token is
  /// stored under), so the device was never discoverable. Worse, when the
  /// future did resolve, the `watch` rebuilt the host provider and disposed
  /// the *running* server out from under the controller.
  ///
  /// [RemoteBootstrap.load] fills it before anything reads it — the whole
  /// UI is gated behind `bootstrapProvider`, so nothing can observe the
  /// empty seed.
  RemoteDeviceIdProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'remoteDeviceIdProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$remoteDeviceIdHash();

  @$internal
  @override
  RemoteDeviceId create() => RemoteDeviceId();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String>(value),
    );
  }
}

String _$remoteDeviceIdHash() => r'f95d7d60a3777919d5b92867b33a10e8cdd6ce14';

/// Stable id of this installation.
///
/// Synchronous on purpose. It used to be a `Future<String>` provider that
/// the host and discovery services read with `ref.watch(...).value` — but
/// that value is null until the future resolves, so both were built with
/// an **empty** device id and advertised `id=""` over mDNS. Remotes drop
/// an advertisement with no id (it is the key their pairing token is
/// stored under), so the device was never discoverable. Worse, when the
/// future did resolve, the `watch` rebuilt the host provider and disposed
/// the *running* server out from under the controller.
///
/// [RemoteBootstrap.load] fills it before anything reads it — the whole
/// UI is gated behind `bootstrapProvider`, so nothing can observe the
/// empty seed.

abstract class _$RemoteDeviceId extends $Notifier<String> {
  String build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<String, String>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<String, String>,
              String,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}

/// The name this device advertises under. A [Notifier] rather than a
/// plain future so a rename immediately re-renders the settings panel
/// (and can be re-advertised without an app restart).

@ProviderFor(RemoteDeviceName)
final remoteDeviceNameProvider = RemoteDeviceNameProvider._();

/// The name this device advertises under. A [Notifier] rather than a
/// plain future so a rename immediately re-renders the settings panel
/// (and can be re-advertised without an app restart).
final class RemoteDeviceNameProvider
    extends $NotifierProvider<RemoteDeviceName, String> {
  /// The name this device advertises under. A [Notifier] rather than a
  /// plain future so a rename immediately re-renders the settings panel
  /// (and can be re-advertised without an app restart).
  RemoteDeviceNameProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'remoteDeviceNameProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$remoteDeviceNameHash();

  @$internal
  @override
  RemoteDeviceName create() => RemoteDeviceName();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String>(value),
    );
  }
}

String _$remoteDeviceNameHash() => r'52ddf7dd02fc77e0d79e40bae4eebea01a3350ac';

/// The name this device advertises under. A [Notifier] rather than a
/// plain future so a rename immediately re-renders the settings panel
/// (and can be re-advertised without an app restart).

abstract class _$RemoteDeviceName extends $Notifier<String> {
  String build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<String, String>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<String, String>,
              String,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}

/// Bonjour in the app, noop under `flutter test`.
///
/// Gated on the test environment rather than on the backend mode: there
/// is no platform channel behind Bonsoir in the test harness, and a
/// `MissingPluginException` from a background browse would surface as an
/// unrelated failure in some other suite. Demo/in-memory mode is a real
/// user-facing mode and keeps real discovery.

@ProviderFor(remoteDiscoveryService)
final remoteDiscoveryServiceProvider = RemoteDiscoveryServiceProvider._();

/// Bonjour in the app, noop under `flutter test`.
///
/// Gated on the test environment rather than on the backend mode: there
/// is no platform channel behind Bonsoir in the test harness, and a
/// `MissingPluginException` from a background browse would surface as an
/// unrelated failure in some other suite. Demo/in-memory mode is a real
/// user-facing mode and keeps real discovery.

final class RemoteDiscoveryServiceProvider
    extends
        $FunctionalProvider<
          RemoteDiscoveryService,
          RemoteDiscoveryService,
          RemoteDiscoveryService
        >
    with $Provider<RemoteDiscoveryService> {
  /// Bonjour in the app, noop under `flutter test`.
  ///
  /// Gated on the test environment rather than on the backend mode: there
  /// is no platform channel behind Bonsoir in the test harness, and a
  /// `MissingPluginException` from a background browse would surface as an
  /// unrelated failure in some other suite. Demo/in-memory mode is a real
  /// user-facing mode and keeps real discovery.
  RemoteDiscoveryServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'remoteDiscoveryServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$remoteDiscoveryServiceHash();

  @$internal
  @override
  $ProviderElement<RemoteDiscoveryService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  RemoteDiscoveryService create(Ref ref) {
    return remoteDiscoveryService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(RemoteDiscoveryService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<RemoteDiscoveryService>(value),
    );
  }
}

String _$remoteDiscoveryServiceHash() =>
    r'9cd457ecbf2bf737de4c56564a9335f8d65f0e2a';

@ProviderFor(remoteControlHost)
final remoteControlHostProvider = RemoteControlHostProvider._();

final class RemoteControlHostProvider
    extends
        $FunctionalProvider<
          RemoteControlHostService,
          RemoteControlHostService,
          RemoteControlHostService
        >
    with $Provider<RemoteControlHostService> {
  RemoteControlHostProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'remoteControlHostProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$remoteControlHostHash();

  @$internal
  @override
  $ProviderElement<RemoteControlHostService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  RemoteControlHostService create(Ref ref) {
    return remoteControlHost(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(RemoteControlHostService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<RemoteControlHostService>(value),
    );
  }
}

String _$remoteControlHostHash() => r'c3dad26b5ff31c9a8c213a525dfb21700fbfc16b';

@ProviderFor(remoteControlClient)
final remoteControlClientProvider = RemoteControlClientProvider._();

final class RemoteControlClientProvider
    extends
        $FunctionalProvider<
          RemoteControlClientService,
          RemoteControlClientService,
          RemoteControlClientService
        >
    with $Provider<RemoteControlClientService> {
  RemoteControlClientProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'remoteControlClientProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$remoteControlClientHash();

  @$internal
  @override
  $ProviderElement<RemoteControlClientService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  RemoteControlClientService create(Ref ref) {
    return remoteControlClient(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(RemoteControlClientService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<RemoteControlClientService>(value),
    );
  }
}

String _$remoteControlClientHash() =>
    r'9d429b01b9ce360a4be65ab6d5ab2ebbf78dadb0';

/// Live status of the local server (running, port, pairing code…).

@ProviderFor(remoteHostStatus)
final remoteHostStatusProvider = RemoteHostStatusProvider._();

/// Live status of the local server (running, port, pairing code…).

final class RemoteHostStatusProvider
    extends
        $FunctionalProvider<
          AsyncValue<RemoteHostStatus>,
          RemoteHostStatus,
          Stream<RemoteHostStatus>
        >
    with $FutureModifier<RemoteHostStatus>, $StreamProvider<RemoteHostStatus> {
  /// Live status of the local server (running, port, pairing code…).
  RemoteHostStatusProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'remoteHostStatusProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$remoteHostStatusHash();

  @$internal
  @override
  $StreamProviderElement<RemoteHostStatus> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<RemoteHostStatus> create(Ref ref) {
    return remoteHostStatus(ref);
  }
}

String _$remoteHostStatusHash() => r'86cdb5cc09593ff37709809ab46de42a4b5d6dfc';

/// Live status of this device's link to a host, when acting as a remote.

@ProviderFor(remoteConnection)
final remoteConnectionProvider = RemoteConnectionProvider._();

/// Live status of this device's link to a host, when acting as a remote.

final class RemoteConnectionProvider
    extends
        $FunctionalProvider<
          AsyncValue<RemoteConnection>,
          RemoteConnection,
          Stream<RemoteConnection>
        >
    with $FutureModifier<RemoteConnection>, $StreamProvider<RemoteConnection> {
  /// Live status of this device's link to a host, when acting as a remote.
  RemoteConnectionProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'remoteConnectionProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$remoteConnectionHash();

  @$internal
  @override
  $StreamProviderElement<RemoteConnection> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<RemoteConnection> create(Ref ref) {
    return remoteConnection(ref);
  }
}

String _$remoteConnectionHash() => r'08912d97ebedacfe5ddc7d187b97418812745d4b';

/// Devices currently advertising on the LAN.
///
/// Auto-dispose: browsing costs battery and wakes the radio, so it runs
/// only while the picker is on screen.

@ProviderFor(discoveredDevices)
final discoveredDevicesProvider = DiscoveredDevicesProvider._();

/// Devices currently advertising on the LAN.
///
/// Auto-dispose: browsing costs battery and wakes the radio, so it runs
/// only while the picker is on screen.

final class DiscoveredDevicesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<RemoteDevice>>,
          List<RemoteDevice>,
          Stream<List<RemoteDevice>>
        >
    with
        $FutureModifier<List<RemoteDevice>>,
        $StreamProvider<List<RemoteDevice>> {
  /// Devices currently advertising on the LAN.
  ///
  /// Auto-dispose: browsing costs battery and wakes the radio, so it runs
  /// only while the picker is on screen.
  DiscoveredDevicesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'discoveredDevicesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$discoveredDevicesHash();

  @$internal
  @override
  $StreamProviderElement<List<RemoteDevice>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<RemoteDevice>> create(Ref ref) {
    return discoveredDevices(ref);
  }
}

String _$discoveredDevicesHash() => r'14dcffdaa1bb5386bbfae3b42e428d3915902f7f';

/// True while this device is driving another one. Read by the play
/// buttons to decide between "play here" and "cast there".

@ProviderFor(isRemotingToDevice)
final isRemotingToDeviceProvider = IsRemotingToDeviceProvider._();

/// True while this device is driving another one. Read by the play
/// buttons to decide between "play here" and "cast there".

final class IsRemotingToDeviceProvider
    extends $FunctionalProvider<bool, bool, bool>
    with $Provider<bool> {
  /// True while this device is driving another one. Read by the play
  /// buttons to decide between "play here" and "cast there".
  IsRemotingToDeviceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'isRemotingToDeviceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$isRemotingToDeviceHash();

  @$internal
  @override
  $ProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  bool create(Ref ref) {
    return isRemotingToDevice(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$isRemotingToDeviceHash() =>
    r'76b12da4323ef0822dcdfb7725f82c688e9b7ede';
