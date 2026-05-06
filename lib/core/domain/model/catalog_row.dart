import 'package:kidflix/core/domain/model/media.dart';

/// Type of a catalog row displayed on the homepage.
///
/// The [saga] and [genre] types may yield multiple [CatalogRow] instances
/// (one per distinct saga / genre). All other types yield at most one row.
enum CatalogRowType {
  continueWatching,
  recentlyAdded,
  favorites,
  saga,
  genre,
  neverWatched,
  downloaded,
}

/// A labelled group of catalog items rendered as a horizontal scrollable
/// row on the homepage.
///
/// `items` is heterogeneous: a row may mix [Movie] and [Series]
/// instances depending on its [type] (e.g. `recentlyAdded` accepts both,
/// `saga` and `genre` only carry films at MVP — see
/// `CatalogApplicationService` and the `series-viewing` design notes).
///
/// A row with an empty [items] list is valid at the domain level — the
/// UI is responsible for hiding empty rows (filtering happens in the
/// application service).
class CatalogRow {
  final String label;
  final CatalogRowType type;
  final List<CatalogItem> items;

  const CatalogRow({
    required this.label,
    required this.type,
    required this.items,
  });
}
