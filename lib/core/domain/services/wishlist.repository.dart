import 'package:kidflix/core/domain/model/wishlist_entry.dart';
import 'package:kidflix/core/domain/model/wishlist_search_result.dart';

/// Contract for the parent's wishlist, proxied server-side by
/// kidflix-api on top of the foyer's Watcharr account
/// (`WATCHARR_WISHLIST_FEATURE.md`).
///
/// The repository deals in **whole entries**: the kidflix-api always
/// returns the full enriched object (Watcharr fields + catalog
/// crossing), and mutations target the Watcharr entry id. There is no
/// per-profile scoping at this layer — the JWT user resolves to a
/// single Watcharr account, and the parent-only gating is enforced by
/// kidflix-api via `X-Profile-Id` + `is_main`.
///
/// `list()` is the single read path. The application controller
/// caches the result in memory and refreshes on a pull-to-refresh or
/// after a mutation.
///
/// Errors:
///
/// - `503 wishlist_not_configured` → no Watcharr account is linked to
///   the foyer. Implementations SHOULD surface this as a typed
///   [WishlistNotConfiguredException] so the UI can render a
///   provisioning hint instead of a generic error.
/// - Anything else (Watcharr upstream errors, network) surfaces as a
///   generic `Exception` / `DioException` — the UI shows a snackbar
///   and a retry.
///
/// Implementations live in `lib/infrastructure/wishlist/`.
abstract interface class WishlistRepository {
  /// Returns every entry in the foyer's Watcharr watchlist, enriched
  /// with the catalog crossing. Order is implementation-defined ; the
  /// application layer sorts before display.
  Future<List<WishlistEntry>> list();

  /// Updates the [status] of an entry. Returns the updated entry as
  /// echoed by the server (catalog crossing refreshed).
  Future<WishlistEntry> updateStatus({
    required int watcharrId,
    required WatchedStatus status,
  });

  /// Removes an entry from the foyer's watchlist.
  Future<void> remove(int watcharrId);

  /// Searches TMDB through Watcharr for movies & series matching
  /// [query]. Returns a (paginated server-side, flattened client-side)
  /// list of [WishlistSearchResult] — items the parent can pick from
  /// to add to the wishlist.
  ///
  /// Caller responsibility: trim and validate the query length
  /// (Watcharr accepts very short strings but returns noisy results
  /// for < 2 chars). The use case layer enforces this.
  ///
  /// Entries that aren't movies or series upstream (people, games)
  /// MUST be filtered out by the implementation — they have no place
  /// in a Kidflix wishlist.
  Future<List<WishlistSearchResult>> search(String query);

  /// Adds a TMDB item to the foyer's Watcharr watchlist with status
  /// `PLANNED`. Returns the freshly-created [WishlistEntry] as echoed
  /// by the server.
  ///
  /// Idempotency: Watcharr rejects a duplicate add with a typed
  /// error (mapped to [WishlistEntryAlreadyExistsException] by the
  /// implementation) — callers should surface a friendly hint
  /// instead of a generic error in that case.
  Future<WishlistEntry> add({
    required int tmdbId,
    required WishlistItemKind kind,
  });
}
