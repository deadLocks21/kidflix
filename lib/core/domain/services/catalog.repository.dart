import 'package:kidflix/core/domain/model/media.dart';

/// Contract for fetching the heterogeneous catalog (movies and series)
/// available to a profile.
///
/// The repository returns raw [CatalogItem] instances mixing [Movie] and
/// [Series]. Row assembly (recently added, sagas, genres, ...) lives in
/// the application service — the repository has no knowledge of rows,
/// the active profile, or UI concerns.
///
/// Implementations live in `lib/infrastructure/catalog/`.
abstract interface class CatalogRepository {
  /// Returns all catalog items the active profile is allowed to see. The
  /// filter is applied **outside** the repository: server-side via
  /// `X-Profile-Id` in HTTP mode (`DioCatalogRepository`), no-op in
  /// in-memory mode (`InMemoryCatalogRepository` returns the full seed,
  /// movies + series).
  Future<List<CatalogItem>> listCatalog();

  /// Returns every catalog item whose [CatalogItem.title] OR
  /// [CatalogItem.originalTitle] contains [query] after case- and
  /// accent-insensitive normalization. The result mixes movies and
  /// series when both match.
  ///
  /// Normalization MUST be applied symmetrically on both sides of the
  /// comparison (query and searched field) via
  /// `lib/shared/text_normalization.dart`.
  ///
  /// Hierarchical age scope (item with `ageCategory ≤ active profile`)
  /// is enforced **outside** the repository: server-side via
  /// `X-Profile-Id` in HTTP mode, not enforced at all in in-memory mode.
  ///
  /// The repository does NOT sort — ordering is the application
  /// service's responsibility. The repository does NOT enforce a
  /// minimum query length — that is the UI/controller's responsibility.
  Future<List<CatalogItem>> searchCatalog({required String query});

  /// Returns the catalog items visible to a SPECIFIC profile, identified
  /// by [profileId], regardless of who the currently-active profile is.
  ///
  /// Used by the downloads manager which needs to resolve metadata for
  /// items downloaded by ANY family profile. Calling
  /// `listCatalog()` from the parent profile would only see items at the
  /// parent's exact age category (per `API.md` § Catalogue), missing the
  /// kid-targeted downloads. Iterating over every profile and unioning
  /// the results bridges that gap without backend changes.
  ///
  /// Implementations:
  /// * HTTP — issues `GET /catalog` with `X-Profile-Id: $profileId`
  ///   pre-set on the per-call `Options.headers`, which the
  ///   `AuthInterceptor` preserves.
  /// * In-memory — equivalent to [listCatalog] (no profile filter
  ///   applied at this layer in the in-memory implementation).
  Future<List<CatalogItem>> listCatalogForProfile(String profileId);
}
