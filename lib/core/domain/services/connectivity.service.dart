/// Reports whether the device currently has any kind of network
/// connectivity (wifi, mobile, ethernet, etc.).
///
/// The contract is intentionally minimal — a single `Stream<bool>` plus a
/// one-shot getter. Callers use the stream to react to transitions and
/// the getter for one-off checks (e.g. deciding the initial source of
/// the catalog at provider build time).
///
/// `true` does **not** guarantee that the backend is reachable — only
/// that the OS reports at least one usable network interface. Callers
/// that need true reachability should still handle HTTP errors and
/// treat them as offline-equivalent.
///
/// Implementations live in `lib/infrastructure/connectivity/`.
abstract interface class ConnectivityService {
  /// Latest known online state. `null`-safe: defaults to `true` before the
  /// first sample arrives, so the app starts in its "normal" online flow
  /// rather than briefly flashing the offline UI on launch.
  bool get isOnline;

  /// Broadcasts every transition between online and offline. Emits the
  /// current value to new subscribers (replay semantics).
  Stream<bool> watch();
}
