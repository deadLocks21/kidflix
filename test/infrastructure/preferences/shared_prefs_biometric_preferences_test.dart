import 'package:flutter_test/flutter_test.dart';
import 'package:kidflix/infrastructure/preferences/shared_prefs_biometric_preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('default false when key absent', () async {
    final prefs = SharedPrefsBiometricPreferences();
    expect(await prefs.isEnabledForProfile('p1'), isFalse);
  });

  test('persists across instances', () async {
    final p1 = SharedPrefsBiometricPreferences();
    await p1.setEnabledForProfile('p1', true);

    final p2 = SharedPrefsBiometricPreferences();
    expect(await p2.isEnabledForProfile('p1'), isTrue);
  });

  test('round-trip true/false', () async {
    final prefs = SharedPrefsBiometricPreferences();
    await prefs.setEnabledForProfile('p1', true);
    expect(await prefs.isEnabledForProfile('p1'), isTrue);
    await prefs.setEnabledForProfile('p1', false);
    expect(await prefs.isEnabledForProfile('p1'), isFalse);
  });

  test('flags are isolated per profile', () async {
    final prefs = SharedPrefsBiometricPreferences();
    await prefs.setEnabledForProfile('p1', true);
    expect(await prefs.isEnabledForProfile('p1'), isTrue);
    expect(await prefs.isEnabledForProfile('p2'), isFalse);
  });

  test('exact key matches the spec literal', () async {
    final prefs = SharedPrefsBiometricPreferences();
    await prefs.setEnabledForProfile('p1', true);
    final raw = await SharedPreferences.getInstance();
    expect(raw.getBool('biometric.enabled.p1'), isTrue);
  });
}
