/// Thrown when a caller attempts to clear the PIN of a profile flagged
/// `isMain`. The main profile's PIN can be changed but never removed.
class CannotClearMainProfilePinException implements Exception {
  final String profileId;

  const CannotClearMainProfilePinException(this.profileId);

  @override
  String toString() => 'CannotClearMainProfilePinException: "$profileId"';
}
