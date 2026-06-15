import 'package:kidflix/core/application/preferences/biometric_preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Prefix for the per-profile biometric opt-in key. The full key is
/// `biometric.enabled.<profileId>`.
const String biometricEnabledKeyPrefix = 'biometric.enabled.';

String biometricEnabledKey(String profileId) =>
    '$biometricEnabledKeyPrefix$profileId';

/// `SharedPreferences`-backed implementation. Default `false` when the
/// key is absent — see contract on the interface.
class SharedPrefsBiometricPreferences implements BiometricPreferences {
  final Future<SharedPreferences> Function() _resolvePrefs;

  SharedPrefsBiometricPreferences({
    Future<SharedPreferences> Function()? resolvePrefs,
  }) : _resolvePrefs = resolvePrefs ?? SharedPreferences.getInstance;

  @override
  Future<bool> isEnabledForProfile(String profileId) async {
    final prefs = await _resolvePrefs();
    return prefs.getBool(biometricEnabledKey(profileId)) ?? false;
  }

  @override
  Future<void> setEnabledForProfile(String profileId, bool enabled) async {
    final prefs = await _resolvePrefs();
    await prefs.setBool(biometricEnabledKey(profileId), enabled);
  }
}
