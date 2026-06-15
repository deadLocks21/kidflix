import 'package:kidflix/core/domain/services/biometric_auth.service.dart';
import 'package:local_auth/local_auth.dart';

/// iOS / Android implementation of [BiometricAuthService] backed by the
/// `local_auth` plugin (Face ID / Touch ID / fingerprint).
///
/// `biometricOnly: true` is deliberate: the device passcode is **not**
/// accepted as a fallback. Only a real biometric unlocks — the app's
/// own 4-digit PIN stays the fallback. This matters for a parental gate
/// (a child who knows the device passcode must not get through).
///
/// Every plugin call is wrapped so the contract holds: methods complete
/// with a `bool` and never throw (`MissingPluginException`,
/// `PlatformException` for not-enrolled / locked-out, user cancel, … all
/// collapse to `false`).
class LocalAuthBiometricService implements BiometricAuthService {
  final LocalAuthentication _auth;

  LocalAuthBiometricService({LocalAuthentication? auth})
    : _auth = auth ?? LocalAuthentication();

  @override
  Future<bool> isAvailable() async {
    try {
      if (!await _auth.isDeviceSupported()) return false;
      final enrolled = await _auth.getAvailableBiometrics();
      return enrolled.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> authenticate({required String reason}) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: true,
      );
    } catch (_) {
      return false;
    }
  }
}
