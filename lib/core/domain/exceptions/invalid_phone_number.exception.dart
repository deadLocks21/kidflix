/// Thrown when a raw phone number input cannot be parsed into a valid
/// `PhoneNumber`. Carries the original input for UI feedback.
class InvalidPhoneNumberException implements Exception {
  final String rawInput;

  const InvalidPhoneNumberException(this.rawInput);

  @override
  String toString() => 'InvalidPhoneNumberException: "$rawInput"';
}
