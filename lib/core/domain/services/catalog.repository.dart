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
}
