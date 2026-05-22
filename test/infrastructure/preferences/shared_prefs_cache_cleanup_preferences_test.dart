import 'package:flutter_test/flutter_test.dart';
import 'package:kidflix/infrastructure/preferences/shared_prefs_cache_cleanup_preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('default true when key absent', () async {
    final prefs = SharedPrefsCacheCleanupPreferences();
    expect(await prefs.isAutoDeleteEnabled(), isTrue);
  });

  test('persists across instances', () async {
    final p1 = SharedPrefsCacheCleanupPreferences();
    await p1.setAutoDeleteEnabled(false);

    final p2 = SharedPrefsCacheCleanupPreferences();
    expect(await p2.isAutoDeleteEnabled(), isFalse);
  });

  test('round-trip true', () async {
    final prefs = SharedPrefsCacheCleanupPreferences();
    await prefs.setAutoDeleteEnabled(false);
    expect(await prefs.isAutoDeleteEnabled(), isFalse);
    await prefs.setAutoDeleteEnabled(true);
    expect(await prefs.isAutoDeleteEnabled(), isTrue);
  });

  test('exact key matches the spec literal', () async {
    final prefs = SharedPrefsCacheCleanupPreferences();
    await prefs.setAutoDeleteEnabled(false);
    final raw = await SharedPreferences.getInstance();
    expect(raw.getBool('download_cleanup.cache_auto_delete_enabled'), isFalse);
  });
}
