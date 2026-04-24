import 'package:kidflix/core/application/dtos/catalog_row.dto.dart';
import 'package:kidflix/core/application/dtos/profile.dto.dart';
import 'package:kidflix/core/application/services/catalog_application.service.dart';

/// Builds the ordered list of homepage rows for a given [ProfileDto].
///
/// Thin wrapper around [CatalogApplicationService] so the UI depends on a
/// stable usecase interface even if row assembly grows in complexity.
class ListHomeCatalogUseCase {
  final CatalogApplicationService _service;

  const ListHomeCatalogUseCase(this._service);

  Future<List<CatalogRowDto>> execute(ProfileDto profile) {
    return _service.buildHomeRowsFor(profile);
  }
}
