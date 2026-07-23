import 'package:kidflix/core/domain/model/remote_device.dart';

/// Port over zero-configuration networking (mDNS / Bonjour).
///
/// Two independent halves that a device may run simultaneously — a
/// device can advertise itself as controllable *and* look for others.
abstract class RemoteDiscoveryService {
  /// Publishes this device on the local network.
  ///
  /// [name] is the user-facing device name; the OS may append a suffix on
  /// a name conflict, which is why the stable id travels in [attributes]
  /// rather than being derived from the service name.
  ///
  /// Idempotent: advertising while already advertising re-publishes with
  /// the new values.
  Future<void> advertise({
    required String name,
    required int port,
    required Map<String, String> attributes,
  });

  Future<void> stopAdvertising();

  /// Starts a browse and emits the full current device list on every
  /// change (found / resolved / lost), most recently seen first.
  ///
  /// The stream is broadcast and replays its latest list to new
  /// subscribers, so a UI opening mid-browse renders immediately.
  Stream<List<RemoteDevice>> discover();

  Future<void> stopDiscovery();

  Future<void> dispose();
}
