import 'package:kidflix/core/domain/model/device.dart';
import 'package:kidflix/core/domain/model/otp_code.dart';
import 'package:kidflix/core/domain/model/phone_number.dart';
import 'package:kidflix/core/domain/model/session.dart';

/// Contract for authenticating a user by phone number and OTP.
///
/// Implementations live in `lib/infrastructure/auth/`.
abstract interface class AuthRepository {
  /// Requests an OTP for [phoneNumber]. Returns the expiration timestamp
  /// of the issued code.
  ///
  /// Throws `UnknownPhoneNumberException` if the number is not registered.
  Future<DateTime> requestOtp(PhoneNumber phoneNumber);

  /// Verifies an OTP [code] for [phoneNumber] on behalf of [device].
  /// Returns a [Session] carrying the JWT and the list of profiles.
  ///
  /// Throws `InvalidOtpException` if [code] does not match the issued OTP.
  /// Throws `OtpExpiredException` if the OTP has expired.
  Future<Session> verifyOtp(
    PhoneNumber phoneNumber,
    OtpCode code,
    Device device,
  );
}
