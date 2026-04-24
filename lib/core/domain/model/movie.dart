import 'package:kidflix/core/domain/model/profile.dart';

/// A movie available in the family catalog.
///
/// Sourced from the backend (or the in-memory fake during MVP) after being
/// normalized from the tinyMediaManager NFO metadata produced by the local
/// conversion script.
///
/// Immutable and equatable by [id]. The [ageCategory] reuses the enum owned
/// by the `profile-selection` capability and is used by the catalog to
/// filter what a profile can see on the homepage.
class Movie {
  final String id;
  final String title;
  final String? originalTitle;
  final int? year;
  final Duration duration;
  final String synopsis;
  final String? tagline;
  final String? posterUrl;
  final String? backdropUrl;
  final AgeCategory ageCategory;
  final List<String> genres;
  final String? sagaId;
  final String? sagaLabel;
  final List<String> director;
  final List<CastMember> cast;
  final DateTime addedAt;

  const Movie({
    required this.id,
    required this.title,
    required this.duration,
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

  /// `true` when the movie is part of a saga.
  bool get hasSaga => sagaId != null && sagaId!.isNotEmpty;

  /// First genre in [genres], used for row grouping. Null when [genres] is
  /// empty.
  String? get primaryGenre => genres.isEmpty ? null : genres.first;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Movie && other.id == id);

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Movie(id: $id, title: $title)';
}

/// A cast member of a movie, ordered by billing importance in the source
/// metadata.
class CastMember {
  final String name;
  final String? role;
  final String? photoUrl;

  const CastMember({required this.name, this.role, this.photoUrl});
}
