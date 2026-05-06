import 'package:kidflix/core/application/dtos/catalog_item.dto.dart';

/// UI-facing projection of a [CatalogRow].
///
/// The [type] is exposed as a string rather than the Domain enum so the
/// UI layer does not depend on the Domain package. The string values
/// match `CatalogRowType.name` to simplify widget-side switches.
///
/// `items` is heterogeneous: `MovieDto` and `SeriesDto` both implement
/// [CatalogItemDto]. Widgets should switch on the runtime type to
/// render the right card variant (cf. `add-series-viewing/design.md`
/// D-1 and `series-viewing` capability spec § Episode card layout).
class CatalogRowDto {
  final String label;
  final String type;
  final List<CatalogItemDto> items;

  const CatalogRowDto({
    required this.label,
    required this.type,
    required this.items,
  });
}
