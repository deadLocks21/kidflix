import 'dart:developer' as developer;

import 'package:kidflix/core/application/preferences/cache_cleanup_preferences.dart';
import 'package:kidflix/core/domain/services/download_cleanup.service.dart';

const Duration cacheRetention = Duration(days: 30);

/// Single-shot startup pass: at the first `Authenticated` transition,
/// the bootstrap calls `unawaited(execute())`. Best-effort — failures
/// are logged but never propagated to the caller, so the home page
/// renders unimpeded.
class RunStartupCacheCleanupUseCase {
  final DownloadCleanupService _service;
  final CacheCleanupPreferences _preferences;

  const RunStartupCacheCleanupUseCase({
    required DownloadCleanupService service,
    required CacheCleanupPreferences preferences,
  })  : _service = service,
        _preferences = preferences;

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
      developer.log(
        'cache cleanup: removed $removed items older than ${cacheRetention.inDays} days',
        name: 'kidflix.downloads.cleanup',
      );
      return removed;
    } catch (e, st) {
      developer.log(
        'cache cleanup: aborted by exception',
        name: 'kidflix.downloads.cleanup',
        level: 900,
        error: e,
        stackTrace: st,
      );
      return 0;
    }
  }
}
