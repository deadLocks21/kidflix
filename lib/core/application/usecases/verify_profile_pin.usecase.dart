import 'package:kidflix/core/application/services/logger_application.service.dart';
import 'package:kidflix/core/domain/model/profile.dart';
import 'package:kidflix/core/domain/services/profile_pin.service.dart';

/// Result of [VerifyProfilePinUseCase.execute].
sealed class VerifyProfilePinResult {
  const VerifyProfilePinResult();
}

class VerifyProfilePinSuccess extends VerifyProfilePinResult {
  const VerifyProfilePinSuccess();
}

class VerifyProfilePinInvalid extends VerifyProfilePinResult {
  const VerifyProfilePinInvalid();
}

/// Verifies a PIN against the bcrypt hash carried by the profile.
class VerifyProfilePinUseCase {
  final ProfilePinService _pin;
  final LoggerApplicationService _logger;

  const VerifyProfilePinUseCase(this._pin, this._logger);

  Future<VerifyProfilePinResult> execute({
    required Profile profile,
    required String rawPin,
  }) async {
    final hash = profile.pinHash;
    if (hash == null || hash.isEmpty) {
      return const VerifyProfilePinSuccess();
    }
    final ok = await _pin.verify(rawPin, hash);
    if (!ok) {
      // PIN volontairement non loggé (donnée sensible).
      await _logger.warn('profile.pin.verify_failed');
      return const VerifyProfilePinInvalid();
    }
    return const VerifyProfilePinSuccess();
  }
}
