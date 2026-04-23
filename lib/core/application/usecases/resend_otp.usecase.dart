import 'package:kidflix/core/domain/exceptions/unknown_phone_number.exception.dart';
import 'package:kidflix/core/domain/model/phone_number.dart';
import 'package:kidflix/core/domain/services/auth.repository.dart';

/// Result of [ResendOtpUseCase.execute].
sealed class ResendOtpResult {
  const ResendOtpResult();
}

class ResendOtpSuccess extends ResendOtpResult {
  final DateTime expiresAt;

  const ResendOtpSuccess(this.expiresAt);
}

class ResendOtpUnknownPhone extends ResendOtpResult {
  const ResendOtpUnknownPhone();
}

/// Re-issues an OTP for a phone that is already in the `OtpRequested`
/// state. The 60-second cooldown is enforced by the UI.
class ResendOtpUseCase {
  final AuthRepository _auth;

  const ResendOtpUseCase(this._auth);

  Future<ResendOtpResult> execute(PhoneNumber phone) async {
    try {
      final expiresAt = await _auth.requestOtp(phone);
      return ResendOtpSuccess(expiresAt);
    } on UnknownPhoneNumberException {
      return const ResendOtpUnknownPhone();
    }
  }
}
