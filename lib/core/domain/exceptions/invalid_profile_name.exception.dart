/// Reason for an [InvalidProfileNameException].
enum InvalidProfileNameReason { empty, tooLong }

/// Thrown when a profile name fails validation (empty after trim, or
/// longer than the allowed maximum).
class InvalidProfileNameException implements Exception {
  final String rawInput;
  final InvalidProfileNameReason reason;

  const InvalidProfileNameException(this.rawInput, this.reason);

  @override
  String toString() =>
      'InvalidProfileNameException(${reason.name}): "$rawInput"';
}
