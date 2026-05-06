/// Application-layer abstraction for the parent's preference about
/// cache auto-deletion. The Domain layer does NOT depend on
/// `SharedPreferences` directly — this interface decouples the policy
/// (kept here) from its persistence (in
/// `lib/infrastructure/preferences/`).
///
/// Default value: `true`. Auto-deletion is enabled out of the box,
/// matching the cache/download split's whole purpose.
abstract interface class CacheCleanupPreferences {
  Future<bool> isAutoDeleteEnabled();
  Future<void> setAutoDeleteEnabled(bool enabled);
}
