/// Thrown when a caller attempts to delete a profile flagged `isMain`.
/// The main profile of an account can never be deleted from the app.
class CannotDeleteMainProfileException implements Exception {
  final String profileId;

  const CannotDeleteMainProfileException(this.profileId);

  @override
  String toString() => 'CannotDeleteMainProfileException: "$profileId"';
}
