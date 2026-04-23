import 'package:kidflix/core/domain/model/phone_number.dart';

/// Thrown when a phone number is not recognized by the authentication
/// backend (no associated user).
class UnknownPhoneNumberException implements Exception {
  final PhoneNumber phoneNumber;

  const UnknownPhoneNumberException(this.phoneNumber);

  @override
  String toString() => 'UnknownPhoneNumberException: ${phoneNumber.e164}';
}
