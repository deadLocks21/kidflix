import 'package:kidflix/core/domain/model/movie.dart';

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

/// A labelled group of movies rendered as a horizontal scrollable row on
/// the homepage.
///
/// A row with an empty [movies] list is valid at the domain level — the UI
/// is responsible for hiding empty rows (filtering happens in the
/// application service).
class CatalogRow {
  final String label;
  final CatalogRowType type;
  final List<Movie> movies;

  const CatalogRow({
    required this.label,
    required this.type,
    required this.movies,
  });
}
