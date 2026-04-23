/// Thrown when an OTP code is syntactically invalid or does not match
/// the expected code for a given phone number.
class InvalidOtpException implements Exception {
  const InvalidOtpException();

  @override
  String toString() => 'InvalidOtpException';
}
