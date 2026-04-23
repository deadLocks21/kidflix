import 'package:kidflix/core/domain/exceptions/invalid_otp.exception.dart';

/// Value object representing a 6-digit OTP code.
class OtpCode {
  final String value;

  const OtpCode._(this.value);

  /// Parses a raw string into an [OtpCode]. Exactly 6 digits are required.
  ///
  /// Throws [InvalidOtpException] if the input is not a 6-digit string.
  factory OtpCode.parse(String input) {
    if (!RegExp(r'^\d{6}$').hasMatch(input)) {
      throw const InvalidOtpException();
    }
    return OtpCode._(input);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is OtpCode && other.value == value);

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}
