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

  const VerifyProfilePinUseCase(this._pin);

  Future<VerifyProfilePinResult> execute({
    required Profile profile,
    required String rawPin,
  }) async {
    final hash = profile.pinHash;
    if (hash == null || hash.isEmpty) {
      return const VerifyProfilePinSuccess();
    }
    final ok = await _pin.verify(rawPin, hash);
    return ok
        ? const VerifyProfilePinSuccess()
        : const VerifyProfilePinInvalid();
  }
}
