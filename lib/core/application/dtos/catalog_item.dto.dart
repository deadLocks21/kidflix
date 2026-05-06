/// Abstract base for catalog row entries shown on the homepage.
///
/// Implemented by `MovieDto` (in `movie.dto.dart`) and `SeriesDto` (in
/// `series.dto.dart`). Not a sealed type because the two subtypes live
/// in different libraries — Dart `sealed` requires same-library
/// membership. The lack of exhaustive-switch enforcement is mitigated
/// by widget tests that cover both render paths.
abstract class CatalogItemDto {
  String get id;
  String get title;
  int? get year;
  String? get posterUrl;
  String get ageCategory;
}
