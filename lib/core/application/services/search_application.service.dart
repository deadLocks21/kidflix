import 'package:kidflix/core/application/dtos/movie.dto.dart';
import 'package:kidflix/core/application/dtos/profile.dto.dart';
import 'package:kidflix/core/domain/model/movie.dart';
import 'package:kidflix/core/domain/model/profile.dart';
import 'package:kidflix/core/domain/services/catalog.repository.dart';

/// Orchestrates movie search for the active profile.
///
/// Delegates the matching/filtering to [CatalogRepository.searchMovies] —
/// which handles normalization and hierarchy internally — then applies the
/// ordering rule (alphabetical by title) and projects results into
/// [MovieDto].
///
/// Normalization, minimum-query-length and debouncing do NOT live here:
/// normalization is the repository's, debouncing and min-length are the
/// UI controller's.
class SearchApplicationService {
  final CatalogRepository _repository;

  const SearchApplicationService(this._repository);

  Future<List<MovieDto>> searchFor({
    required String query,
    required ProfileDto profile,
  }) async {
    final category = AgeCategory.values.firstWhere(
      (c) => c.name == profile.ageCategory,
    );
    final matches = await _repository.searchMovies(
      query: query,
      upToAgeCategory: category,
    );
    final sorted = [...matches]..sort(_byTitle);
    return sorted.map(MovieDto.fromDomain).toList(growable: false);
  }

  static int _byTitle(Movie a, Movie b) => a.title.compareTo(b.title);
}
