/// Thrown when a backend returns 404 for a `/profiles/{id}/*` route — the
/// profile id no longer exists or never existed in the authenticated account.
///
/// Application-layer usecases catch this exception and map it to their
/// existing `unknownProfile` failure flag (defense in depth: the local
/// pre-check on `session.profiles` catches the obvious cases, this exception
/// covers the race-condition where the profile vanished between read and
/// mutation).
class UnknownProfileException implements Exception {
  final String profileId;

  const UnknownProfileException(this.profileId);

  @override
  String toString() => 'UnknownProfileException: "$profileId"';
}
