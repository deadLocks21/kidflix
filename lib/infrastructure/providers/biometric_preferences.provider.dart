import 'package:kidflix/core/application/preferences/biometric_preferences.dart';
import 'package:kidflix/infrastructure/preferences/shared_prefs_biometric_preferences.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'biometric_preferences.provider.g.dart';

@Riverpod(keepAlive: true)
BiometricPreferences biometricPreferences(Ref ref) {
  return SharedPrefsBiometricPreferences();
}
