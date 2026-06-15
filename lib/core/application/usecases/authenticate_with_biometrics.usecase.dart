import 'package:kidflix/core/application/preferences/biometric_preferences.dart';
import 'package:kidflix/core/application/services/logger_application.service.dart';
import 'package:kidflix/core/domain/services/biometric_auth.service.dart';

/// Decides whether a profile can be unlocked by biometrics and, when so,
/// prompts the OS sheet. Shared by both the profile-unlock flow
/// (`PinRequired`) and the management gate (`ManagementPinRequired`).
///
/// All outcomes other than "authenticated" collapse to `false`: the
/// caller's fallback is always the same (keep the PIN pad), so a richer
/// result type would add ceremony without payoff — matching the plain
/// `bool` philosophy of `BiometricAuthService`.
class AuthenticateWithBiometricsUseCase {
  final BiometricPreferences _prefs;
  final BiometricAuthService _biometrics;
  final LoggerApplicationService _logger;

  const AuthenticateWithBiometricsUseCase(
    this._prefs,
    this._biometrics,
    this._logger,
  );

  /// Whether biometric unlock should be *offered* for [profileId] —
  /// enabled by the user AND supported/enrolled on the device. Does not
  /// prompt. Used by the UI to decide whether to auto-prompt and to
  /// show the manual "use biometrics" button.
  Future<bool> isOfferedFor(String profileId) async {
    if (!await _prefs.isEnabledForProfile(profileId)) return false;
    return _biometrics.isAvailable();
  }

  /// Prompts biometrics for [profileId] when offered. Returns `true`
  /// only on successful authentication. [reason] is the localized sheet
  /// message.
  Future<bool> execute({
    required String profileId,
    required String reason,
  }) async {
    if (!await isOfferedFor(profileId)) return false;
    final ok = await _biometrics.authenticate(reason: reason);
    if (!ok) {
      await _logger.info('profile.biometric.auth_failed');
    }
    return ok;
  }
}
