import 'package:kidflix/core/domain/services/biometric_auth.service.dart';

/// Fallback implementation used on platforms without `local_auth`
/// support (Windows, Linux, web, …). Biometrics are never available, so
/// the PIN gate behaves exactly as before — unchanged.
class NoopBiometricAuthService implements BiometricAuthService {
  const NoopBiometricAuthService();

  @override
  Future<bool> isAvailable() async => false;

  @override
  Future<bool> authenticate({required String reason}) async => false;
}
