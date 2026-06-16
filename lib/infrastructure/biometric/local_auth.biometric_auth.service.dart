import 'package:kidflix/core/domain/services/biometric_auth.service.dart';
import 'package:local_auth_platform_interface/local_auth_platform_interface.dart';

/// iOS / Android implementation of [BiometricAuthService].
///
/// Talks to [LocalAuthPlatform.instance] — the federated platform
/// interface — rather than the `local_auth` umbrella package. This is
/// deliberate: depending on the umbrella would also pull
/// `local_auth_windows`, whose native code fails to compile on recent
/// MSVC toolchains. We register only the Android / Apple implementations
/// (see `pubspec.yaml`) and use a no-op on desktop, so the Windows plugin
/// is never built. The instance is provided by the implementation that
/// registered itself for the current platform (Android / Apple).
///
/// `biometricOnly: true` is deliberate: the device passcode is **not**
/// accepted as a fallback. Only a real biometric unlocks — the app's own
/// 4-digit PIN stays the fallback. This matters for a parental gate (a
/// child who knows the device passcode must not get through).
///
/// Every call is wrapped so the contract holds: methods complete with a
/// `bool` and never throw (`MissingPluginException`, not-enrolled,
/// locked-out, user cancel, … all collapse to `false`).
class LocalAuthBiometricService implements BiometricAuthService {
  final LocalAuthPlatform _auth;

  LocalAuthBiometricService({LocalAuthPlatform? auth})
    : _auth = auth ?? LocalAuthPlatform.instance;

  @override
  Future<bool> isAvailable() async {
    try {
      if (!await _auth.isDeviceSupported()) return false;
      final enrolled = await _auth.getEnrolledBiometrics();
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
        authMessages: const <AuthMessages>[],
        options: const AuthenticationOptions(biometricOnly: true),
      );
    } catch (_) {
      return false;
    }
  }
}
