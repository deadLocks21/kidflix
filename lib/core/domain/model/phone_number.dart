import 'package:kidflix/core/domain/exceptions/invalid_phone_number.exception.dart';

/// Value object representing a French mobile phone number.
///
/// The raw input is normalized (whitespace, dots and hyphens are stripped)
/// and validated against `^0[67]\d{8}$` before being stored internally in
/// E.164 form (`+33XXXXXXXXX`).
class PhoneNumber {
  /// The E.164 representation, e.g. `+33612345678`.
  final String e164;

  const PhoneNumber._(this.e164);

  /// Parses a raw string into a [PhoneNumber].
  ///
  /// Throws [InvalidPhoneNumberException] if the normalized input does not
  /// match the expected pattern.
  factory PhoneNumber.parse(String input) {
    final stripped = input.replaceAll(RegExp(r'[\s.\-]'), '');
    if (!RegExp(r'^0[67]\d{8}$').hasMatch(stripped)) {
      throw InvalidPhoneNumberException(input);
    }
    return PhoneNumber._('+33${stripped.substring(1)}');
  }

  /// Builds a [PhoneNumber] from a pre-normalized E.164 string.
  /// Used for deserialization from persisted storage.
  factory PhoneNumber.fromE164(String e164) {
    if (!RegExp(r'^\+33[67]\d{8}$').hasMatch(e164)) {
      throw InvalidPhoneNumberException(e164);
    }
    return PhoneNumber._(e164);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is PhoneNumber && other.e164 == e164);

  @override
  int get hashCode => e164.hashCode;

  @override
  String toString() => e164;
}
