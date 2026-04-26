/// Contract for the OS-level kids lock — Android Lock Task Mode.
///
/// The implementation lives in `lib/infrastructure/kids_lock/`. On
/// Android, the bridge to native code is a `MethodChannel`. On other
/// platforms a noop fallback is used (the OS layer has no equivalent
/// — the UI layer handles the cross-platform side of the lock).
///
/// All three methods complete with a `bool` and never throw. The
/// caller is expected to react to the boolean (e.g. update local UI
/// state) but not to handle exceptions.
abstract interface class KidsLockService {
  /// Engages the OS-level lock.
  ///
  /// Returns `true` when the lock is successfully engaged. Returns
  /// `false` when the platform does not support it, the native plugin
  /// is missing, the system prompt was declined by the user, or any
  /// recoverable native exception occurred.
  Future<bool> startLock();

  /// Disengages the OS-level lock.
  ///
  /// Idempotent: returns `true` even if no lock was active (semantics
  /// "nothing to stop"). Returns `false` only on unexpected native
  /// failure on a platform where the lock is otherwise supported.
  Future<bool> stopLock();

  /// Returns the current OS-level lock state.
  ///
  /// `false` on platforms where the lock is not supported.
  Future<bool> isLocked();
}
