import 'package:kidflix/core/application/dtos/catalog_item.dto.dart';
import 'package:kidflix/core/application/dtos/profile.dto.dart';
import 'package:kidflix/core/application/services/logger_application.service.dart';
import 'package:kidflix/core/application/services/search_application.service.dart';

/// Thin wrapper around [SearchApplicationService] exposed to the UI layer.
///
/// Returns mixed [CatalogItemDto] entries — the search UI switches on
/// the runtime DTO type to render movie cards or series cards.
class SearchMoviesUseCase {
  final SearchApplicationService _service;
  final LoggerApplicationService _logger;

  const SearchMoviesUseCase(this._service, this._logger);

  Future<List<CatalogItemDto>> execute({
    required String query,
    required ProfileDto profile,
  }) async {
    try {
      return await _service.searchFor(query: query, profile: profile);
    } catch (e, st) {
      // Le texte de la requête n'est jamais loggué (donnée sensible).
      await _logger.warn('search.failed', error: e, stack: st);
      rethrow;
    }
  }
}
