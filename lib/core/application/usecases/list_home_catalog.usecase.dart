import 'package:kidflix/core/application/dtos/catalog_row.dto.dart';
import 'package:kidflix/core/application/dtos/profile.dto.dart';
import 'package:kidflix/core/application/services/catalog_application.service.dart';
import 'package:kidflix/core/application/services/logger_application.service.dart';
import 'package:kidflix/core/domain/model/download_entry.dart';
import 'package:kidflix/core/domain/model/favorite.dart';

/// Builds the ordered list of homepage rows for a given [ProfileDto].
///
/// Thin wrapper around [CatalogApplicationService] so the UI depends on a
/// stable usecase interface even if row assembly grows in complexity.
class ListHomeCatalogUseCase {
  final CatalogApplicationService _service;
  final LoggerApplicationService _logger;

  const ListHomeCatalogUseCase(this._service, this._logger);

  Future<List<CatalogRowDto>> execute(
    ProfileDto profile, {
    List<DownloadEntry> downloads = const [],
    List<Favorite> favorites = const [],
    Set<String> seenMovieIds = const {},
    int? shuffleSeed,
  }) async {
    try {
      return await _service.buildHomeRowsFor(
        profile,
        downloads: downloads,
        favorites: favorites,
        seenMovieIds: seenMovieIds,
        shuffleSeed: shuffleSeed,
      );
    } catch (e, st) {
      // On loggue puis on relance : le provider `homeCatalogRows` laisse
      // volontairement l'exception remonter pour afficher l'UI de réessai.
      await _logger.warn('catalog.home.load_failed', error: e, stack: st);
      rethrow;
    }
  }
}
