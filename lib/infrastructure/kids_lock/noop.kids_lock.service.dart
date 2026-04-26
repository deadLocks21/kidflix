import 'package:kidflix/core/domain/services/kids_lock.service.dart';

/// Fallback implementation used on iOS, web, macOS, Linux, Windows
/// where Android's `startLockTask` has no equivalent.
///
/// Performs no I/O, no platform call, no log. The UI layer of the
/// kids lock (control suppression in the player) still applies on
/// these platforms — only the OS layer is a no-op.
class NoopKidsLockService implements KidsLockService {
  const NoopKidsLockService();

  @override
  Future<bool> startLock() async => false;

  @override
  Future<bool> stopLock() async => true;

  @override
  Future<bool> isLocked() async => false;
}
