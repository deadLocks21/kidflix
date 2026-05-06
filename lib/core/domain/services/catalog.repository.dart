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
}
