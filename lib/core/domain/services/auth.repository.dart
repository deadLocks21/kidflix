import 'package:kidflix/core/domain/model/device.dart';
import 'package:kidflix/core/domain/model/otp_code.dart';
import 'package:kidflix/core/domain/model/phone_number.dart';
import 'package:kidflix/core/domain/model/profile.dart';
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
  /// Throws `DeviceAlreadyRegisteredException` if [device] is already
  /// attached to another user account.
  Future<Session> verifyOtp(
    PhoneNumber phoneNumber,
    OtpCode code,
    Device device,
  );

  /// Returns the up-to-date list of profiles owned by the user identified
  /// by the current JWT, including each profile's `pinHash` and `isMain`.
  /// Used to resync after the initial login when external mutations could
  /// have happened (new profile on another device, PIN updated, profile
  /// deleted).
  ///
  /// The JWT and device id are injected as headers by the central Dio's
  /// `AuthInterceptor` (HTTP implementation) or read from the in-memory
  /// store (in-memory implementation). The HTTP route is exempt from
  /// `X-Profile-Id` injection (bootstrap route).
  ///
  /// Callable only after a successful `verifyOtp`. The in-memory
  /// implementation throws `StateError` if called before any login.
  Future<List<Profile>> fetchProfiles();
}
