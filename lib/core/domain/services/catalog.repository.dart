import 'package:kidflix/core/domain/model/movie.dart';

/// Contract for fetching the catalog of movies available to a profile.
///
/// The repository returns raw movies. Row assembly (recently added, sagas,
/// genres, ...) lives in the application service — the repository has no
/// knowledge of rows, the active profile, or UI concerns.
///
/// Implementations live in `lib/infrastructure/catalog/`.
abstract interface class CatalogRepository {
  /// Returns all movies the active profile is allowed to see. The filter
  /// is applied **outside** the repository: server-side via `X-Profile-Id`
  /// in HTTP mode (`DioCatalogRepository`), no-op in in-memory mode
  /// (`InMemoryCatalogRepository` returns the full seed).
  Future<List<Movie>> listMoviesFor();

  /// Returns every movie whose [Movie.title] OR [Movie.originalTitle]
  /// contains [query] after case- and accent-insensitive normalization.
  ///
  /// Normalization MUST be applied symmetrically on both sides of the
  /// comparison (query and searched field) via
  /// `lib/shared/text_normalization.dart`.
  ///
  /// Hierarchical age scope (movies with `ageCategory ≤ active profile`)
  /// is enforced **outside** the repository: server-side via
  /// `X-Profile-Id` in HTTP mode, not enforced at all in in-memory mode.
  ///
  /// The repository does NOT sort — ordering is the application service's
  /// responsibility. The repository does NOT enforce a minimum query
  /// length — that is the UI/controller's responsibility.
  Future<List<Movie>> searchMovies({required String query});
}
