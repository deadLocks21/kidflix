import 'package:kidflix/core/application/preferences/cache_cleanup_preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String cacheAutoDeleteEnabledKey =
    'download_cleanup.cache_auto_delete_enabled';

/// `SharedPreferences`-backed implementation. Default `true` when the
/// key is absent — see contract on the interface.
class SharedPrefsCacheCleanupPreferences implements CacheCleanupPreferences {
  final Future<SharedPreferences> Function() _resolvePrefs;

  SharedPrefsCacheCleanupPreferences({
    Future<SharedPreferences> Function()? resolvePrefs,
  }) : _resolvePrefs = resolvePrefs ?? SharedPreferences.getInstance;

  @override
  Future<bool> isAutoDeleteEnabled() async {
    final prefs = await _resolvePrefs();
    return prefs.getBool(cacheAutoDeleteEnabledKey) ?? true;
  }

  @override
  Future<void> setAutoDeleteEnabled(bool enabled) async {
    final prefs = await _resolvePrefs();
    await prefs.setBool(cacheAutoDeleteEnabledKey, enabled);
  }
}
