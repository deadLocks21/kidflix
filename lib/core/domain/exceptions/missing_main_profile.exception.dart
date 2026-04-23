/// Thrown when an operation that requires the main profile of an account
/// is invoked but no profile in the current session has `isMain == true`.
/// This indicates a malformed source of truth (backend or fake data).
class MissingMainProfileException implements Exception {
  const MissingMainProfileException();

  @override
  String toString() => 'MissingMainProfileException';
}
