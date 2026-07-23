import 'dart:async';

import 'package:bonsoir/bonsoir.dart';
import 'package:kidflix/core/application/remote/remote_protocol.dart';
import 'package:kidflix/core/application/services/logger_application.service.dart';
import 'package:kidflix/core/domain/model/remote_device.dart';
import 'package:kidflix/core/domain/services/remote_discovery.service.dart';

/// mDNS / Bonjour adapter.
///
/// Bonjour rather than a raw UDP broadcast on purpose: since iOS 14 both
/// multicast and broadcast sockets need the `com.apple.developer.
/// networking.multicast` entitlement, which Apple grants case by case.
/// The system Bonjour APIs need no such approval — only the
/// `NSLocalNetworkUsageDescription` / `NSBonjourServices` Info.plist keys
/// and the one-time "Local Network" consent prompt.
class BonsoirRemoteDiscoveryService implements RemoteDiscoveryService {
  /// This device's own id, so its own advertisement is filtered out of
  /// the browse results — every host sees itself otherwise.
  ///
  /// A callback, not a value: resolved at browse time so the provider
  /// never has to `watch` the id and rebuild a live browse.
  final String Function() resolveSelfDeviceId;

  final LoggerApplicationService _logger;

  BonsoirRemoteDiscoveryService({
    required this.resolveSelfDeviceId,
    required LoggerApplicationService logger,
  }) : _logger = logger;

  BonsoirBroadcast? _broadcast;
  BonsoirDiscovery? _discovery;
  StreamSubscription<BonsoirDiscoveryEvent>? _discoverySub;

  /// Keyed by device id (from the TXT record), not by mDNS service name:
  /// the OS renames a service on a conflict ("Salon (2)"), and we still
  /// want one entry per physical device.
  final _devices = <String, RemoteDevice>{};
  StreamController<List<RemoteDevice>>? _devicesController;

  @override
  Future<void> advertise({
    required String name,
    required int port,
    required Map<String, String> attributes,
  }) async {
    await stopAdvertising();
    final broadcast = BonsoirBroadcast(
      service: BonsoirService(
        name: name,
        type: RemoteProtocol.serviceType,
        port: port,
        attributes: attributes,
      ),
    );
    _broadcast = broadcast;
    await broadcast.initialize();
    await broadcast.start();
    unawaited(
      _logger.info('remote.discovery.advertising', attrs: {'port': port}),
    );
  }

  @override
  Future<void> stopAdvertising() async {
    final broadcast = _broadcast;
    _broadcast = null;
    if (broadcast == null) return;
    try {
      if (!broadcast.isStopped) await broadcast.stop();
    } catch (e, st) {
      unawaited(
        _logger.warn('remote.discovery.stop_advertise_failed', error: e, stack: st),
      );
    }
  }

  @override
  Stream<List<RemoteDevice>> discover() {
    final existing = _devicesController;
    if (existing != null && !existing.isClosed) {
      return _withReplay(existing.stream);
    }
    final controller = StreamController<List<RemoteDevice>>.broadcast();
    _devicesController = controller;
    unawaited(_startDiscovery());
    return _withReplay(controller.stream);
  }

  /// Prepends the devices already found so a UI subscribing mid-browse
  /// paints immediately rather than waiting for the next mDNS event.
  Stream<List<RemoteDevice>> _withReplay(Stream<List<RemoteDevice>> source) =>
      Stream<List<RemoteDevice>>.multi((controller) {
        controller.add(_snapshot());
        final sub = source.listen(
          controller.add,
          onError: controller.addError,
          onDone: controller.close,
        );
        controller.onCancel = sub.cancel;
      });

  Future<void> _startDiscovery() async {
    try {
      final discovery = BonsoirDiscovery(type: RemoteProtocol.serviceType);
      _discovery = discovery;
      await discovery.initialize();
      _discoverySub = discovery.eventStream?.listen(
        (event) => _onDiscoveryEvent(discovery, event),
        onError: (Object e, StackTrace st) => unawaited(
          _logger.warn('remote.discovery.stream_error', error: e, stack: st),
        ),
      );
      await discovery.start();
    } catch (e, st) {
      unawaited(_logger.warn('remote.discovery.failed', error: e, stack: st));
      _devicesController?.addError(e, st);
    }
  }

  void _onDiscoveryEvent(
    BonsoirDiscovery discovery,
    BonsoirDiscoveryEvent event,
  ) {
    switch (event) {
      case BonsoirDiscoveryServiceFoundEvent(:final service):
        // A found service carries no addresses yet — ask the platform to
        // resolve it, which comes back as a `…ServiceResolvedEvent`.
        discovery.serviceResolver.resolveService(service);
      case BonsoirDiscoveryServiceResolvedEvent(:final service):
      case BonsoirDiscoveryServiceUpdatedEvent(:final service):
        final device = _toDevice(service);
        if (device == null) return;
        _devices[device.id] = device;
        _emit();
      case BonsoirDiscoveryServiceLostEvent(:final service):
        final id = service.attributes[RemoteProtocol.txtDeviceId];
        if (id == null) return;
        if (_devices.remove(id) != null) _emit();
      case _:
        break;
    }
  }

  /// Maps a resolved mDNS service to a device, or null when it is not a
  /// usable Kidflix host: our own advertisement, an unresolved service,
  /// or one missing the id we key everything on.
  RemoteDevice? _toDevice(BonsoirService service) {
    final id = service.attributes[RemoteProtocol.txtDeviceId];
    if (id == null || id.isEmpty) return null;
    if (id == resolveSelfDeviceId()) return null;
    // Keep every advertised address, not just the first: a host running a
    // VPN or a container runtime advertises virtual interfaces alongside
    // its real one, and they are not ordered usefully.
    final candidates = [
      ...service.hostAddresses.where((a) => a.isNotEmpty),
      if (service.hostname case final hostname?)
        if (hostname.isNotEmpty) hostname,
    ];
    if (candidates.isEmpty) return null;
    return RemoteDevice(
      id: id,
      name: service.attributes[RemoteProtocol.txtDeviceName] ?? service.name,
      host: candidates.first,
      hostCandidates: candidates,
      port: service.port,
      platform: service.attributes[RemoteProtocol.txtPlatform] ?? 'unknown',
      protocolVersion:
          int.tryParse(service.attributes[RemoteProtocol.txtVersion] ?? '') ?? 1,
    );
  }

  List<RemoteDevice> _snapshot() => List.unmodifiable(_devices.values);

  void _emit() {
    final controller = _devicesController;
    if (controller == null || controller.isClosed) return;
    controller.add(_snapshot());
  }

  @override
  Future<void> stopDiscovery() async {
    await _discoverySub?.cancel();
    _discoverySub = null;
    final discovery = _discovery;
    _discovery = null;
    if (discovery != null) {
      try {
        if (!discovery.isStopped) await discovery.stop();
      } catch (e, st) {
        unawaited(
          _logger.warn('remote.discovery.stop_failed', error: e, stack: st),
        );
      }
    }
    _devices.clear();
    await _devicesController?.close();
    _devicesController = null;
  }

  @override
  Future<void> dispose() async {
    await stopAdvertising();
    await stopDiscovery();
  }
}
