import 'package:kidflix/core/application/services/logger_application.service.dart';
import 'package:kidflix/core/domain/exceptions/invalid_phone_number.exception.dart';
import 'package:kidflix/core/domain/exceptions/unknown_phone_number.exception.dart';
import 'package:kidflix/core/domain/model/phone_number.dart';
import 'package:kidflix/core/domain/services/auth.repository.dart';

/// Result of [RequestOtpUseCase.execute].
sealed class RequestOtpResult {
  const RequestOtpResult();
}

class RequestOtpSuccess extends RequestOtpResult {
  final PhoneNumber phone;
  final DateTime expiresAt;

  const RequestOtpSuccess({required this.phone, required this.expiresAt});
}

class RequestOtpInvalidPhone extends RequestOtpResult {
  final String rawInput;

  const RequestOtpInvalidPhone(this.rawInput);
}

class RequestOtpUnknownPhone extends RequestOtpResult {
  const RequestOtpUnknownPhone();
}

/// Toute autre défaillance lors de l'appel backend : réseau injoignable,
/// timeout, 5xx, 429, réponse malformée. L'UI affiche un message générique
/// et invite à réessayer.
class RequestOtpFailure extends RequestOtpResult {
  const RequestOtpFailure();
}

/// Parses a raw phone string and asks the backend to issue an OTP.
class RequestOtpUseCase {
  final AuthRepository _auth;
  final LoggerApplicationService _logger;

  const RequestOtpUseCase(this._auth, this._logger);

  Future<RequestOtpResult> execute(String rawPhone) async {
    final PhoneNumber phone;
    try {
      phone = PhoneNumber.parse(rawPhone);
    } on InvalidPhoneNumberException catch (e) {
      return RequestOtpInvalidPhone(e.rawInput);
    }
    try {
      final expiresAt = await _auth.requestOtp(phone);
      return RequestOtpSuccess(phone: phone, expiresAt: expiresAt);
    } on UnknownPhoneNumberException catch (e, st) {
      await _logger.warn(
        'auth.request_otp.unknown_phone',
        attrs: {'phone': phone.e164},
        error: e,
        stack: st,
      );
      return const RequestOtpUnknownPhone();
    } catch (e, st) {
      // Numéro volontairement non loggé (donnée sensible).
      await _logger.warn('auth.request_otp.failed', error: e, stack: st);
      return const RequestOtpFailure();
    }
  }
}
