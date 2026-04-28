import 'package:kidflix/core/application/dtos/movie.dto.dart';
import 'package:kidflix/core/application/dtos/profile.dto.dart';
import 'package:kidflix/core/domain/model/movie.dart';
import 'package:kidflix/core/domain/services/catalog.repository.dart';

/// Orchestrates movie search for the active profile.
///
/// Delegates the matching to [CatalogRepository.searchMovies] then applies
/// the ordering rule (alphabetical by title) and projects results into
/// [MovieDto].
///
/// The hierarchical age scope (movies with `ageCategory ≤ active profile`)
/// is enforced **outside** this service: server-side via `X-Profile-Id` in
/// HTTP mode, not enforced at all in in-memory mode. The [ProfileDto]
/// parameter is preserved on `searchFor` for future ranking/highlighting
/// decisions that may consume profile metadata other than the age category.
///
/// Normalization, minimum-query-length and debouncing do NOT live here:
/// normalization is the repository's (in-memory) or the backend's (HTTP),
/// debouncing and min-length are the UI controller's.
class SearchApplicationService {
  final CatalogRepository _repository;

  const SearchApplicationService(this._repository);

  Future<List<MovieDto>> searchFor({
    required String query,
    required ProfileDto profile,
  }) async {
    final matches = await _repository.searchMovies(query: query);
    final sorted = [...matches]..sort(_byTitle);
    return sorted.map(MovieDto.fromDomain).toList(growable: false);
  }

  static int _byTitle(Movie a, Movie b) => a.title.compareTo(b.title);
}
