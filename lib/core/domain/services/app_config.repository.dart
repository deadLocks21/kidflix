/// Contract for persisting cross-cutting application configuration that
/// must survive app restarts and may be edited by the user at runtime.
///
/// Currently exposes a single setting: the API base URL used by the Dio
/// HTTP client and the repository providers. Implementations live in
/// `lib/infrastructure/app_config/`.
abstract interface class AppConfigRepository {
  /// Reads the persisted API base URL. Returns `null` when the user has
  /// never explicitly configured one — callers should fall back to the
  /// compile-time default in that case.
  Future<String?> readApiBaseUrl();

  /// Persists [url]. An empty string is allowed and means "switch back to
  /// in-memory mode" (the repository providers select their in-memory
  /// implementations when the base URL is empty).
  Future<void> writeApiBaseUrl(String url);
}
