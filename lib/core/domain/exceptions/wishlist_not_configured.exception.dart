/// Thrown by a [WishlistRepository] when the foyer (= phone-number
/// user) has no Watcharr account provisioned server-side.
///
/// Maps the `503 wishlist_not_configured` response documented in
/// `WATCHARR_WISHLIST_FEATURE.md`. The UI uses it to render a
/// "feature non activée" placeholder rather than a generic error +
/// retry — there is nothing to retry until the parent contacts the
/// admin.
class WishlistNotConfiguredException implements Exception {
  const WishlistNotConfiguredException();

  @override
  String toString() => 'WishlistNotConfiguredException()';
}
