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

/// Parses a raw phone string and asks the backend to issue an OTP.
class RequestOtpUseCase {
  final AuthRepository _auth;

  const RequestOtpUseCase(this._auth);

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
    } on UnknownPhoneNumberException {
      return const RequestOtpUnknownPhone();
    }
  }
}
