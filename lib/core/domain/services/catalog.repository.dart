import 'package:kidflix/core/domain/model/movie.dart';
import 'package:kidflix/core/domain/model/profile.dart';

/// Contract for fetching the catalog of movies available to a profile.
///
/// The repository returns raw movies. Row assembly (recently added, sagas,
/// genres, ...) lives in the application service — the repository has no
/// knowledge of rows, the active profile, or UI concerns.
///
/// Implementations live in `lib/infrastructure/catalog/`.
abstract interface class CatalogRepository {
  /// Returns all movies whose [Movie.ageCategory] equals [ageCategory]
  /// exactly. No hierarchical expansion is performed at this layer.
  Future<List<Movie>> listMoviesFor(AgeCategory ageCategory);

  /// Returns every movie whose [Movie.ageCategory] is less than or equal
  /// to [upToAgeCategory] (per the documented hierarchy of [AgeCategory])
  /// and whose [Movie.title] OR [Movie.originalTitle] contains [query]
  /// after case- and accent-insensitive normalization.
  ///
  /// Normalization MUST be applied symmetrically on both sides of the
  /// comparison (query and searched field) via
  /// `lib/shared/text_normalization.dart`.
  ///
  /// The repository does NOT sort — ordering is the application service's
  /// responsibility. The repository does NOT enforce a minimum query
  /// length — that is the UI/controller's responsibility.
  ///
  /// A future HTTP implementation SHALL map this method to a single
  /// backend endpoint, preserving the 1:1 signature.
  Future<List<Movie>> searchMovies({
    required String query,
    required AgeCategory upToAgeCategory,
  });
}
