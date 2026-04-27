import 'package:kidflix/core/application/dtos/age_category_wire.dart';
import 'package:kidflix/core/domain/model/movie.dart';
import 'package:kidflix/core/domain/model/profile.dart';

/// Wire-format DTO for a [Movie] — direction of flow: `JSON → Domain` only.
///
/// The client never serializes movies to the backend, so no `toJson` is
/// exposed. JSON keys are `snake_case` per `API.md` § Catalogue.
///
/// `duration_seconds` lives as an `int` on the DTO and is projected into a
/// [Duration] inside [toDomain]; this preserves the convention that
/// `fromJson` describes the post-JSON-parse Dart primitive shape and
/// `toDomain` performs the wire-to-Domain projection.
class RemoteMovieDto {
  final String id;
  final String title;
  final String? originalTitle;
  final int? year;
  final int durationSeconds;
  final String synopsis;
  final String? tagline;
  final String? posterUrl;
  final String? backdropUrl;
  final AgeCategory ageCategory;
  final List<String> genres;
  final String? sagaId;
  final String? sagaLabel;
  final List<String> director;
  final List<RemoteCastMemberDto> cast;
  final DateTime addedAt;

  const RemoteMovieDto({
    required this.id,
    required this.title,
    required this.durationSeconds,
    required this.synopsis,
    required this.ageCategory,
    required this.genres,
    required this.director,
    required this.cast,
    required this.addedAt,
    this.originalTitle,
    this.year,
    this.tagline,
    this.posterUrl,
    this.backdropUrl,
    this.sagaId,
    this.sagaLabel,
  });

  factory RemoteMovieDto.fromJson(Map<String, dynamic> json) => RemoteMovieDto(
    id: json['id'] as String,
    title: json['title'] as String,
    originalTitle: json['original_title'] as String?,
    year: json['year'] as int?,
    durationSeconds: json['duration_seconds'] as int,
    synopsis: json['synopsis'] as String,
    tagline: json['tagline'] as String?,
    posterUrl: json['poster_url'] as String?,
    backdropUrl: json['backdrop_url'] as String?,
    ageCategory: ageCategoryFromWire(json['age_category'] as String),
    genres: (json['genres'] as List).cast<String>(),
    sagaId: json['saga_id'] as String?,
    sagaLabel: json['saga_label'] as String?,
    director: (json['director'] as List).cast<String>(),
    cast: (json['cast'] as List)
        .cast<Map<String, dynamic>>()
        .map(RemoteCastMemberDto.fromJson)
        .toList(growable: false),
    addedAt: DateTime.parse(json['added_at'] as String),
  );

  Movie toDomain() => Movie(
    id: id,
    title: title,
    originalTitle: originalTitle,
    year: year,
    duration: Duration(seconds: durationSeconds),
    synopsis: synopsis,
    tagline: tagline,
    posterUrl: posterUrl,
    backdropUrl: backdropUrl,
    ageCategory: ageCategory,
    genres: genres,
    sagaId: sagaId,
    sagaLabel: sagaLabel,
    director: director,
    cast: cast.map((c) => c.toDomain()).toList(growable: false),
    addedAt: addedAt,
  );
}

/// Wire-format DTO for a single entry of [Movie.cast].
class RemoteCastMemberDto {
  final String name;
  final String? role;
  final String? photoUrl;

  const RemoteCastMemberDto({required this.name, this.role, this.photoUrl});

  factory RemoteCastMemberDto.fromJson(Map<String, dynamic> json) =>
      RemoteCastMemberDto(
        name: json['name'] as String,
        role: json['role'] as String?,
        photoUrl: json['photo_url'] as String?,
      );

  CastMember toDomain() =>
      CastMember(name: name, role: role, photoUrl: photoUrl);
}
