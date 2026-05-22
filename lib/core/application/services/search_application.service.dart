import 'package:kidflix/core/application/dtos/catalog_item.dto.dart';
import 'package:kidflix/core/application/dtos/movie.dto.dart';
import 'package:kidflix/core/application/dtos/profile.dto.dart';
import 'package:kidflix/core/application/dtos/series.dto.dart';
import 'package:kidflix/core/domain/model/media.dart';
import 'package:kidflix/core/domain/services/catalog.repository.dart';

/// Orchestrates catalog search for the active profile.
///
/// Delegates the matching to [CatalogRepository.searchCatalog] then
/// applies the ordering rule (alphabetical by title) and projects each
/// result into its corresponding DTO ([MovieDto] for movies, [SeriesDto]
/// for series). Both implement [CatalogItemDto] so the UI can render
/// them via the same `CatalogRowWidget` switch logic.
///
/// The hierarchical age scope (items with `ageCategory ≤ active
/// profile`) is enforced **outside** this service: server-side via
/// `X-Profile-Id` in HTTP mode, not enforced at all in in-memory mode.
/// The [ProfileDto] parameter is preserved on `searchFor` for future
/// ranking/highlighting decisions that may consume profile metadata.
///
/// Normalization, minimum-query-length and debouncing do NOT live here:
/// normalization is the repository's (in-memory) or the backend's (HTTP),
/// debouncing and min-length are the UI controller's.
class SearchApplicationService {
  final CatalogRepository _repository;

  const SearchApplicationService(this._repository);

  Future<List<CatalogItemDto>> searchFor({
    required String query,
    required ProfileDto profile,
  }) async {
    final matches = await _repository.searchCatalog(query: query);
    final sorted = [...matches]..sort(_byTitle);
    return sorted.map<CatalogItemDto>(_project).toList(growable: false);
  }

  static int _byTitle(CatalogItem a, CatalogItem b) =>
      a.title.compareTo(b.title);

  static CatalogItemDto _project(CatalogItem item) => switch (item) {
    Movie() => MovieDto.fromDomain(item),
    Series() => SeriesDto.fromDomain(item),
  };
}
