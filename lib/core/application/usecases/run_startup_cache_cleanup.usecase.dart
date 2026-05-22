import 'package:kidflix/core/application/preferences/cache_cleanup_preferences.dart';
import 'package:kidflix/core/application/services/logger_application.service.dart';
import 'package:kidflix/core/domain/services/download_cleanup.service.dart';

const Duration cacheRetention = Duration(days: 30);

/// Single-shot startup pass: at the first `Authenticated` transition,
/// the bootstrap calls `unawaited(execute())`. Best-effort — failures
/// are logged but never propagated to the caller, so the home page
/// renders unimpeded.
class RunStartupCacheCleanupUseCase {
  final DownloadCleanupService _service;
  final CacheCleanupPreferences _preferences;
  final LoggerApplicationService _logger;

  const RunStartupCacheCleanupUseCase({
    required DownloadCleanupService service,
    required CacheCleanupPreferences preferences,
    required LoggerApplicationService logger,
  }) : _service = service,
       _preferences = preferences,
       _logger = logger;

  /// Returns the number of items deleted in this pass. Always
  /// completes; never throws.
  Future<int> execute() async {
    try {
      final enabled = await _preferences.isAutoDeleteEnabled();
      if (!enabled) return 0;

      final removed = await _service.runCacheCleanup(
        olderThan: cacheRetention,
        now: DateTime.now(),
      );
      await _logger.info(
        'cache.cleanup.done',
        attrs: {'removed': removed, 'retention.days': cacheRetention.inDays},
      );
      return removed;
    } catch (e, st) {
      await _logger.warn('cache.cleanup.failed', error: e, stack: st);
      return 0;
    }
  }
}
