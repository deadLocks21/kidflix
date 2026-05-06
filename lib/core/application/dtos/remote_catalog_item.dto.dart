import 'package:kidflix/core/application/dtos/remote_movie.dto.dart';
import 'package:kidflix/core/application/dtos/remote_series.dto.dart';
import 'package:kidflix/core/domain/model/media.dart';

/// Parses a single entry of the `/catalog` (or `/catalog/search`)
/// response — discriminated by the top-level `kind` field — into a
/// [CatalogItem] domain entity.
///
/// Throws [FormatException] when [json] is missing the `kind` key or
/// carries an unknown value (fail-fast: any deviation indicates a
/// backend contract violation).
CatalogItem catalogItemFromJson(Map<String, dynamic> json) {
  final kind = json['kind'];
  switch (kind) {
    case 'movie':
      return RemoteMovieDto.fromJson(json).toDomain();
    case 'series':
      return RemoteSeriesCatalogDto.fromJson(json).toDomain();
    default:
      throw FormatException('Unknown catalog kind: $kind');
  }
}
