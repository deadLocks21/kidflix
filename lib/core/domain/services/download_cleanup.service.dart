/// Domain service that enforces the cache auto-deletion policy.
///
/// `runCacheCleanup` enumerates every download with `kind == cache`
/// whose `lastPlayedAt` is non-null and older than [olderThan] relative
/// to [now], and deletes each via the underlying `DownloadRepository`.
///
/// Items with `lastPlayedAt == null` (never played) are NEVER cleaned
/// by this rule — they remain on disk indefinitely until the user
/// manually deletes them or actually plays them (after which the rule
/// applies on the next pass). Items with `kind == download` are
/// excluded outright.
///
/// The service SHALL be idempotent: calling it twice in a row with the
/// same arguments leaves state unchanged after the first call. It is
/// best-effort: a per-item delete failure is logged and the loop
/// continues with the next item.
///
/// Implementations live in `lib/infrastructure/downloads/`.
abstract interface class DownloadCleanupService {
  /// Runs one pass of cache cleanup. Returns the number of items
  /// successfully deleted.
  Future<int> runCacheCleanup({
    required Duration olderThan,
    required DateTime now,
  });
}
