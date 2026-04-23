/// Thrown when the double-entry confirmation of a PIN change does not
/// match — the `newPin` and the `confirmPin` differ. No mutation is
/// performed and no bcrypt hashing is computed before this check.
class PinConfirmationMismatchException implements Exception {
  const PinConfirmationMismatchException();

  @override
  String toString() => 'PinConfirmationMismatchException';
}
