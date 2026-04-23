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

/// Verifies an OTP code entered by the user. On success returns the
/// authenticated [Session].
class VerifyOtpUseCase {
  final AuthRepository _auth;

  const VerifyOtpUseCase(this._auth);

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
      return VerifyOtpSuccess(session);
    } on InvalidOtpException {
      return const VerifyOtpInvalidCode();
    } on OtpExpiredException {
      return const VerifyOtpExpired();
    }
  }
}
