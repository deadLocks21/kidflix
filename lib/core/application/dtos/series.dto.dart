import 'package:kidflix/core/application/dtos/catalog_item.dto.dart';
import 'package:kidflix/core/domain/model/media.dart';

/// Compact UI-facing projection of a [Series], suitable for catalog
/// card rendering.
///
/// `seasonsCount` and `episodesCount` are the server-side computed
/// integers from `/catalog`. The hierarchical seasons / episodes
/// structure is **not** carried in this DTO — it lives on the Domain
/// [Series] and is re-fetched via `SeriesRepository.findById` when
/// the detail modal opens.
class SeriesDto implements CatalogItemDto {
  @override
  final String id;
  @override
  final String title;
  @override
  final int? year;
  @override
  final String? posterUrl;
  @override
  final String ageCategory;
  final int seasonsCount;
  final int episodesCount;

  const SeriesDto({
    required this.id,
    required this.title,
    required this.ageCategory,
    required this.seasonsCount,
    required this.episodesCount,
    this.year,
    this.posterUrl,
  });

  factory SeriesDto.fromDomain(Series series) => SeriesDto(
    id: series.id,
    title: series.title,
    year: series.year,
    posterUrl: series.posterUrl,
    ageCategory: series.ageCategory.name,
    seasonsCount: series.seasonsCount,
    episodesCount: series.episodesCount,
  );
}
