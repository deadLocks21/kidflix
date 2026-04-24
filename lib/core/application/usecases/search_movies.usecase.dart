import 'package:kidflix/core/application/dtos/movie.dto.dart';
import 'package:kidflix/core/application/dtos/profile.dto.dart';
import 'package:kidflix/core/application/services/search_application.service.dart';

/// Thin wrapper around [SearchApplicationService] exposed to the UI layer.
class SearchMoviesUseCase {
  final SearchApplicationService _service;

  const SearchMoviesUseCase(this._service);

  Future<List<MovieDto>> execute({
    required String query,
    required ProfileDto profile,
  }) {
    return _service.searchFor(query: query, profile: profile);
  }
}
