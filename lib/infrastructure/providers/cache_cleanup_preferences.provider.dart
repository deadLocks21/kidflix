import 'package:kidflix/core/application/preferences/cache_cleanup_preferences.dart';
import 'package:kidflix/infrastructure/preferences/shared_prefs_cache_cleanup_preferences.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'cache_cleanup_preferences.provider.g.dart';

@Riverpod(keepAlive: true)
CacheCleanupPreferences cacheCleanupPreferences(Ref ref) {
  return SharedPrefsCacheCleanupPreferences();
}
