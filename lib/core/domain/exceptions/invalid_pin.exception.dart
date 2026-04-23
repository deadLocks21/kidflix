/// Thrown when a profile PIN verification fails.
class InvalidPinException implements Exception {
  const InvalidPinException();

  @override
  String toString() => 'InvalidPinException';
}
