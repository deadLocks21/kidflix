import 'package:kidflix/core/domain/model/remote_device.dart';
import 'package:kidflix/core/domain/services/remote_discovery.service.dart';

/// Discovery that finds nothing and advertises nothing.
///
/// Used under `flutter test` and on the in-memory backend, where the
/// Bonsoir platform channels have no implementation and would throw
/// `MissingPluginException`. Mirrors the noop/in-memory selection the
/// other platform-dependent services use.
class NoopRemoteDiscoveryService implements RemoteDiscoveryService {
  const NoopRemoteDiscoveryService();

  @override
  Future<void> advertise({
    required String name,
    required int port,
    required Map<String, String> attributes,
  }) async {}

  @override
  Future<void> stopAdvertising() async {}

  @override
  Stream<List<RemoteDevice>> discover() =>
      Stream<List<RemoteDevice>>.value(const []);

  @override
  Future<void> stopDiscovery() async {}

  @override
  Future<void> dispose() async {}
}
