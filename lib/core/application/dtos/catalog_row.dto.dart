import 'package:kidflix/core/application/dtos/movie.dto.dart';
import 'package:kidflix/core/domain/model/catalog_row.dart';

/// UI-facing projection of a [CatalogRow].
///
/// The [type] is exposed as a string rather than the Domain enum so the UI
/// layer does not depend on the Domain package. The string values match
/// [CatalogRowType.name] to simplify widget-side switches.
class CatalogRowDto {
  final String label;
  final String type;
  final List<MovieDto> movies;

  const CatalogRowDto({
    required this.label,
    required this.type,
    required this.movies,
  });
}
