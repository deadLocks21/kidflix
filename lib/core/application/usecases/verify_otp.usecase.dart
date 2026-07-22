import 'package:kidflix/core/application/services/logger_application.service.dart';
import 'package:kidflix/core/domain/exceptions/device_already_registered.exception.dart';
import 'package:kidflix/core/domain/exceptions/invalid_otp.exception.dart';
import 'package:kidflix/core/domain/exceptions/otp_expired.exception.dart';
import 'package:kidflix/core/domain/model/device.dart';
import 'package:kidflix/core/domain/model/otp_code.dart';
import 'package:kidflix/core/domain/model/phone_number.dart';
import 'package:kidflix/core/domain/model/session.dart';
import 'package:kidflix/core/domain/services/auth.repository.dart';

/// Result of [VerifyOtpUseCase.execute].
sealed class VerifyOtpResult {
  const VerifyOtpResult();
}

class VerifyOtpSuccess extends VerifyOtpResult {
  final Session session;

  const VerifyOtpSuccess(this.session);
}

class VerifyOtpInvalidCode extends VerifyOtpResult {
  const VerifyOtpInvalidCode();
}

class VerifyOtpExpired extends VerifyOtpResult {
  const VerifyOtpExpired();
}

/// L'appareil est déjà rattaché à un autre compte (`409
/// device_already_registered`). Situation stable, et non une panne :
/// réessayer ne débloquera rien, l'UI le dit plutôt que d'inviter à
/// retenter.
class VerifyOtpDeviceAlreadyRegistered extends VerifyOtpResult {
  const VerifyOtpDeviceAlreadyRegistered();
}

/// Toute autre défaillance lors de l'appel backend : réseau injoignable,
/// timeout, 5xx, 429, réponse malformée. L'UI affiche un message générique
/// et invite à réessayer.
class VerifyOtpFailure extends VerifyOtpResult {
  const VerifyOtpFailure();
}

/// Verifies an OTP code entered by the user. On success returns the
/// authenticated [Session].
class VerifyOtpUseCase {
  final AuthRepository _auth;
  final LoggerApplicationService _logger;

  const VerifyOtpUseCase(this._auth, this._logger);

  Future<VerifyOtpResult> execute({
    required PhoneNumber phone,
    required String rawCode,
    required Device device,
  }) async {
    final OtpCode code;
    try {
      code = OtpCode.parse(rawCode);
    } on InvalidOtpException {
      return const VerifyOtpInvalidCode();
    }
    try {
      final session = await _auth.verifyOtp(phone, code, device);
      await _logger.info('auth.verify_otp.success');
      return VerifyOtpSuccess(session);
    } on InvalidOtpException catch (e, st) {
      // Code OTP volontairement non loggé (donnée sensible).
      await _logger.warn('auth.verify_otp.failed', error: e, stack: st);
      return const VerifyOtpInvalidCode();
    } on OtpExpiredException catch (e, st) {
      await _logger.warn('auth.verify_otp.failed', error: e, stack: st);
      return const VerifyOtpExpired();
    } on DeviceAlreadyRegisteredException catch (e, st) {
      await _logger.warn('auth.verify_otp.failed', error: e, stack: st);
      return const VerifyOtpDeviceAlreadyRegistered();
    } catch (e, st) {
      // Filet générique : réseau, timeout, 5xx, 429, payload malformé.
      // Sans lui, l'exception traverse le controller et fige l'écran OTP
      // sur son indicateur de chargement.
      await _logger.warn('auth.verify_otp.failed', error: e, stack: st);
      return const VerifyOtpFailure();
    }
  }
}
