import 'package:kidflix/core/application/dtos/catalog_item.dto.dart';

/// Catalog row entry for the "Continuer à regarder" row.
///
/// Wraps an [inner] `MovieDto` or `SeriesDto` and carries the resume
/// [progress] (a fraction in `[0, 1]`) so the home row can overlay a
/// thin progress bar on the poster. The wrapper is exclusive to that
/// row — every other row keeps emitting bare `MovieDto` / `SeriesDto`.
///
/// `CatalogItemDto` getters delegate to [inner] so the existing search /
/// modal navigation paths keep working when the row's tap callback
/// receives the unwrapped item.
class ContinueWatchingCardDto implements CatalogItemDto {
  final CatalogItemDto inner;
  final double progress;

  ContinueWatchingCardDto({
    required this.inner,
    required double progress,
  }) : progress = progress.isNaN ? 0.0 : progress.clamp(0.0, 1.0);

  @override
  String get id => inner.id;
  @override
  String get title => inner.title;
  @override
  int? get year => inner.year;
  @override
  String? get posterUrl => inner.posterUrl;
  @override
  String get ageCategory => inner.ageCategory;
}
