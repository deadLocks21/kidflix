import 'package:kidflix/core/domain/services/app_config.repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persistent [AppConfigRepository] backed by `shared_preferences`.
class SharedPreferencesAppConfigRepository implements AppConfigRepository {
  static const _kApiBaseUrl = 'kidflix.api_base_url';

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  @override
  Future<String?> readApiBaseUrl() async {
    final prefs = await _prefs;
    return prefs.getString(_kApiBaseUrl);
  }

  @override
  Future<void> writeApiBaseUrl(String url) async {
    final prefs = await _prefs;
    await prefs.setString(_kApiBaseUrl, url);
  }
}
