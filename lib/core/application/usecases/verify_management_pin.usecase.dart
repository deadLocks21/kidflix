import 'package:kidflix/core/application/services/logger_application.service.dart';
import 'package:kidflix/core/domain/model/profile.dart';
import 'package:kidflix/core/domain/services/profile_pin.service.dart';

/// Result of [VerifyManagementPinUseCase.execute].
sealed class VerifyManagementPinResult {
  const VerifyManagementPinResult();
}

class VerifyManagementPinSuccess extends VerifyManagementPinResult {
  const VerifyManagementPinSuccess();
}

class VerifyManagementPinInvalid extends VerifyManagementPinResult {
  const VerifyManagementPinInvalid();
}

/// Verifies a raw PIN against the bcrypt hash of the main profile.
/// Offloaded to an isolate via the underlying [ProfilePinService] so the UI
/// thread is not blocked.
class VerifyManagementPinUseCase {
  final ProfilePinService _pin;
  final LoggerApplicationService _logger;

  const VerifyManagementPinUseCase(this._pin, this._logger);

  Future<VerifyManagementPinResult> execute({
    required Profile mainProfile,
    required String rawPin,
  }) async {
    final hash = mainProfile.pinHash;
    if (hash == null || hash.isEmpty) {
      // The main profile is required to have a PIN by design; if this
      // invariant ever breaks, treat as invalid rather than silently pass.
      await _logger.warn('profile.management.verify_failed');
      return const VerifyManagementPinInvalid();
    }
    final ok = await _pin.verify(rawPin, hash);
    if (!ok) {
      await _logger.warn('profile.management.verify_failed');
      return const VerifyManagementPinInvalid();
    }
    return const VerifyManagementPinSuccess();
  }
}
