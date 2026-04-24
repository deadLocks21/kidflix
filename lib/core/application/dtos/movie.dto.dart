import 'package:kidflix/core/domain/model/movie.dart';

/// Compact UI-facing projection of a [Movie], suitable for card rendering.
class MovieDto {
  final String id;
  final String title;
  final int? year;
  final Duration duration;
  final String? posterUrl;

  const MovieDto({
    required this.id,
    required this.title,
    required this.duration,
    this.year,
    this.posterUrl,
  });

  factory MovieDto.fromDomain(Movie movie) => MovieDto(
    id: movie.id,
    title: movie.title,
    year: movie.year,
    duration: movie.duration,
    posterUrl: movie.posterUrl,
  );
}

/// Full detail projection used by the movie detail modal.
///
/// Expands [MovieDto] with narrative fields (synopsis, tagline), visual
/// backdrop, genres, director(s) and the **top 5** cast members — the
/// application service is responsible for enforcing the cap so the rule
/// stays consistent when the HTTP backend replaces the in-memory fake.
class MovieDetailDto {
  final String id;
  final String title;
  final String? originalTitle;
  final int? year;
  final Duration duration;
  final String synopsis;
  final String? tagline;
  final String? posterUrl;
  final String? backdropUrl;
  final String ageCategory;
  final List<String> genres;
  final List<String> director;
  final List<CastMemberDto> topCast;

  const MovieDetailDto({
    required this.id,
    required this.title,
    required this.duration,
    required this.synopsis,
    required this.ageCategory,
    required this.genres,
    required this.director,
    required this.topCast,
    this.originalTitle,
    this.year,
    this.tagline,
    this.posterUrl,
    this.backdropUrl,
  });

  factory MovieDetailDto.fromDomain(Movie movie) => MovieDetailDto(
    id: movie.id,
    title: movie.title,
    originalTitle: movie.originalTitle,
    year: movie.year,
    duration: movie.duration,
    synopsis: movie.synopsis,
    tagline: movie.tagline,
    posterUrl: movie.posterUrl,
    backdropUrl: movie.backdropUrl,
    ageCategory: movie.ageCategory.name,
    genres: List.unmodifiable(movie.genres),
    director: List.unmodifiable(movie.director),
    topCast: movie.cast
        .take(5)
        .map(CastMemberDto.fromDomain)
        .toList(growable: false),
  );
}

/// UI-facing projection of a [CastMember].
class CastMemberDto {
  final String name;
  final String? role;
  final String? photoUrl;

  const CastMemberDto({required this.name, this.role, this.photoUrl});

  factory CastMemberDto.fromDomain(CastMember member) => CastMemberDto(
    name: member.name,
    role: member.role,
    photoUrl: member.photoUrl,
  );
}
