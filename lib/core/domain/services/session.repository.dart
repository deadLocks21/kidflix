import 'package:kidflix/core/domain/model/device.dart';
import 'package:kidflix/core/domain/model/session.dart';

/// Contract for persisting a [Session] across application restarts.
///
/// Implementations live in `lib/infrastructure/session/`.
abstract interface class SessionRepository {
  /// Reads the persisted session. Returns `null` when no session has been
  /// persisted yet, or when the persisted data is incomplete/corrupt.
  Future<Session?> read();

  /// Persists [session]. Overwrites any previously persisted session.
  Future<void> write(Session session);

  /// Clears session data (JWT, profiles) while preserving the device id.
  /// Called on logout and when partial/corrupt data is detected.
  Future<void> clearSessionPreserveDevice();

  /// Clears everything, including the device id. Not used by the current
  /// flow but exposed for completeness (e.g. "wipe this installation").
  Future<void> clear();

  /// Reads the persisted [Device]; generates a new UUID-based device at
  /// first call and persists it.
  Future<Device> readOrCreateDevice();
}
