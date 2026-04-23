/// Thrown when an OTP verification is attempted past the recorded
/// expiration timestamp.
class OtpExpiredException implements Exception {
  const OtpExpiredException();

  @override
  String toString() => 'OtpExpiredException';
}
