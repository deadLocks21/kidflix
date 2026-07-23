import 'package:kidflix/core/domain/model/remote_device.dart';
import 'package:kidflix/core/domain/services/remote_control_client.service.dart';
import 'package:kidflix/core/domain/services/remote_control_host.service.dart';
import 'package:kidflix/core/domain/services/remote_discovery.service.dart';
import 'package:kidflix/core/domain/services/remote_pairing.repository.dart';
import 'package:kidflix/infrastructure/providers/logger.service_provider.dart';
import 'package:kidflix/infrastructure/remote_control/bonsoir.remote_discovery.service.dart';
import 'package:kidflix/infrastructure/remote_control/http.remote_control_host.service.dart';
import 'package:kidflix/infrastructure/remote_control/noop.remote_discovery.service.dart';
import 'package:kidflix/infrastructure/remote_control/remote_device_identity.dart';
import 'package:kidflix/infrastructure/remote_control/shared_prefs.remote_pairing.repository.dart';
import 'package:kidflix/infrastructure/remote_control/ws.remote_control_client.service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'remote_control.providers.g.dart';

@Riverpod(keepAlive: true)
RemotePairingRepository remotePairingRepository(Ref ref) =>
    SharedPrefsRemotePairingRepository();

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
@Riverpod(keepAlive: true)
class RemoteDeviceId extends _$RemoteDeviceId {
  @override
  String build() => '';

  Future<void> load() async {
    state = await loadOrCreateDeviceId();
  }
}

/// The name this device advertises under. A [Notifier] rather than a
/// plain future so a rename immediately re-renders the settings panel
/// (and can be re-advertised without an app restart).
@Riverpod(keepAlive: true)
class RemoteDeviceName extends _$RemoteDeviceName {
  @override
  String build() => defaultDeviceName();

  Future<void> load() async {
    state = await loadDeviceName();
  }

  Future<void> rename(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    await saveDeviceName(trimmed);
    state = trimmed;
  }
}

/// Bonjour in the app, noop under `flutter test`.
///
/// Gated on the test environment rather than on the backend mode: there
/// is no platform channel behind Bonsoir in the test harness, and a
/// `MissingPluginException` from a background browse would surface as an
/// unrelated failure in some other suite. Demo/in-memory mode is a real
/// user-facing mode and keeps real discovery.
@Riverpod(keepAlive: true)
RemoteDiscoveryService remoteDiscoveryService(Ref ref) {
  if (isRunningUnderTest) return const NoopRemoteDiscoveryService();
  final service = BonsoirRemoteDiscoveryService(
    // Read lazily rather than watched: watching would rebuild this
    // provider — and dispose a live browse — the moment the id changes.
    resolveSelfDeviceId: () => ref.read(remoteDeviceIdProvider),
    logger: ref.watch(loggerProvider),
  );
  ref.onDispose(service.dispose);
  return service;
}

@Riverpod(keepAlive: true)
RemoteControlHostService remoteControlHost(Ref ref) {
  final service = HttpRemoteControlHostService(
    resolveDeviceId: () => ref.read(remoteDeviceIdProvider),
    resolveDeviceName: () => ref.read(remoteDeviceNameProvider),
    platformName: currentPlatformName(),
    pairing: ref.watch(remotePairingRepositoryProvider),
    discovery: ref.watch(remoteDiscoveryServiceProvider),
    logger: ref.watch(loggerProvider),
  );
  ref.onDispose(service.dispose);
  return service;
}

@Riverpod(keepAlive: true)
RemoteControlClientService remoteControlClient(Ref ref) {
  final service = WsRemoteControlClientService(
    pairing: ref.watch(remotePairingRepositoryProvider),
    logger: ref.watch(loggerProvider),
  );
  ref.onDispose(service.dispose);
  return service;
}

/// Live status of the local server (running, port, pairing code…).
@Riverpod(keepAlive: true)
Stream<RemoteHostStatus> remoteHostStatus(Ref ref) =>
    ref.watch(remoteControlHostProvider).statusStream;

/// Live status of this device's link to a host, when acting as a remote.
@Riverpod(keepAlive: true)
Stream<RemoteConnection> remoteConnection(Ref ref) =>
    ref.watch(remoteControlClientProvider).connectionStream;

/// Devices currently advertising on the LAN.
///
/// Auto-dispose: browsing costs battery and wakes the radio, so it runs
/// only while the picker is on screen.
@riverpod
Stream<List<RemoteDevice>> discoveredDevices(Ref ref) {
  final discovery = ref.watch(remoteDiscoveryServiceProvider);
  ref.onDispose(() => discovery.stopDiscovery());
  return discovery.discover();
}

/// True while this device is driving another one. Read by the play
/// buttons to decide between "play here" and "cast there".
@Riverpod(keepAlive: true)
bool isRemotingToDevice(Ref ref) {
  final connection = ref.watch(remoteConnectionProvider).value;
  return connection?.isConnected ?? false;
}
