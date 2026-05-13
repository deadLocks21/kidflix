/// Thrown by a [WishlistRepository] when an `add` would create a
/// duplicate entry in the foyer's Watcharr watchlist.
///
/// Maps the `403 watched entry exists` response Watcharr returns when
/// the same `(tmdbId, contentType)` is already in the user's list
/// (regardless of status, including soft-deleted entries that haven't
/// been restored yet).
///
/// The UI uses it to render a friendly "déjà dans la liste" snackbar
/// instead of a generic error. Adding the same item twice is harmless
/// from a user POV — the entry is already there — so no retry is
/// proposed.
class WishlistEntryAlreadyExistsException implements Exception {
  const WishlistEntryAlreadyExistsException();

  @override
  String toString() => 'WishlistEntryAlreadyExistsException()';
}
