import 'package:kidflix/core/application/dtos/age_category_wire.dart';
import 'package:kidflix/core/application/dtos/remote_movie.dto.dart';
import 'package:kidflix/core/domain/model/media.dart';
import 'package:kidflix/core/domain/model/profile.dart';

/// Wire-format DTO for the `kind: "series"` shape returned by `GET /catalog`
/// and `GET /catalog/search`. Direction of flow: `JSON → Domain` only.
///
/// `seasons_count` and `episodes_count` are server-computed integers
/// projected verbatim ; the local [Series] hierarchical structure
/// (`seasons`) is **always empty** when produced from this DTO — fetching
/// the seasons / episodes requires a follow-up call to `GET /series/{id}`
/// (see [RemoteSeriesDetailDto]).
class RemoteSeriesCatalogDto {
  final String id;
  final String title;
  final String? originalTitle;
  final int? year;
  final int seasonsCount;
  final int episodesCount;
  final String synopsis;
  final String? tagline;
  final String? posterUrl;
  final String? backdropUrl;
  final String? logoUrl;
  final String? trailerUrl;
  final AgeCategory ageCategory;
  final List<String> genres;
  final String? sagaId;
  final String? sagaLabel;
  final List<String> director;
  final List<RemoteCastMemberDto> cast;
  final DateTime addedAt;

  const RemoteSeriesCatalogDto({
    required this.id,
    required this.title,
    required this.seasonsCount,
    required this.episodesCount,
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
    this.logoUrl,
    this.trailerUrl,
    this.sagaId,
    this.sagaLabel,
  });

  factory RemoteSeriesCatalogDto.fromJson(Map<String, dynamic> json) =>
      RemoteSeriesCatalogDto(
        id: json['id'] as String,
        title: json['title'] as String,
        originalTitle: json['original_title'] as String?,
        year: json['year'] as int?,
        seasonsCount: json['seasons_count'] as int,
        episodesCount: json['episodes_count'] as int,
        synopsis: json['synopsis'] as String,
        tagline: json['tagline'] as String?,
        posterUrl: json['poster_url'] as String?,
        backdropUrl: json['backdrop_url'] as String?,
        logoUrl: json['logo_url'] as String?,
        trailerUrl: json['trailer_url'] as String?,
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

  Series toDomain() => Series(
    id: id,
    title: title,
    originalTitle: originalTitle,
    year: year,
    synopsis: synopsis,
    tagline: tagline,
    posterUrl: posterUrl,
    backdropUrl: backdropUrl,
    logoUrl: logoUrl,
    trailerUrl: trailerUrl,
    ageCategory: ageCategory,
    genres: genres,
    sagaId: sagaId,
    sagaLabel: sagaLabel,
    director: director,
    cast: cast.map((c) => c.toDomain()).toList(growable: false),
    addedAt: addedAt,
    seasonsCount: seasonsCount,
    episodesCount: episodesCount,
    seasons: const [],
  );
}

/// Wire-format DTO for the response of `GET /series/{id}` — carries the
/// full saisons / épisodes hierarchy.
///
/// Unlike [RemoteSeriesCatalogDto], the detail payload does **not**
/// include `seasons_count` / `episodes_count` ; we recompute them
/// locally from `seasons.length` and the sum of `season.episodes.length`
/// when projecting to the [Series] domain entity.
class RemoteSeriesDetailDto {
  final String id;
  final String title;
  final String? originalTitle;
  final int? year;
  final String synopsis;
  final String? tagline;
  final String? posterUrl;
  final String? backdropUrl;
  final String? logoUrl;
  final String? trailerUrl;
  final AgeCategory ageCategory;
  final List<String> genres;
  final String? sagaId;
  final String? sagaLabel;
  final List<String> director;
  final List<RemoteCastMemberDto> cast;
  final DateTime addedAt;
  final List<RemoteSeasonDto> seasons;

  const RemoteSeriesDetailDto({
    required this.id,
    required this.title,
    required this.synopsis,
    required this.ageCategory,
    required this.genres,
    required this.director,
    required this.cast,
    required this.addedAt,
    required this.seasons,
    this.originalTitle,
    this.year,
    this.tagline,
    this.posterUrl,
    this.backdropUrl,
    this.logoUrl,
    this.trailerUrl,
    this.sagaId,
    this.sagaLabel,
  });

  factory RemoteSeriesDetailDto.fromJson(Map<String, dynamic> json) =>
      RemoteSeriesDetailDto(
        id: json['id'] as String,
        title: json['title'] as String,
        originalTitle: json['original_title'] as String?,
        year: json['year'] as int?,
        synopsis: json['synopsis'] as String,
        tagline: json['tagline'] as String?,
        posterUrl: json['poster_url'] as String?,
        backdropUrl: json['backdrop_url'] as String?,
        logoUrl: json['logo_url'] as String?,
        trailerUrl: json['trailer_url'] as String?,
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
        seasons: (json['seasons'] as List)
            .cast<Map<String, dynamic>>()
            .map(RemoteSeasonDto.fromJson)
            .toList(growable: false),
      );

  Series toDomain() {
    final domainSeasons = seasons
        .map((s) => s.toDomain(seriesId: id, ageCategory: ageCategory))
        .toList(growable: false);
    final episodesCount = domainSeasons.fold<int>(
      0,
      (sum, s) => sum + s.episodes.length,
    );
    return Series(
      id: id,
      title: title,
      originalTitle: originalTitle,
      year: year,
      synopsis: synopsis,
      tagline: tagline,
      posterUrl: posterUrl,
      backdropUrl: backdropUrl,
      logoUrl: logoUrl,
      trailerUrl: trailerUrl,
      ageCategory: ageCategory,
      genres: genres,
      sagaId: sagaId,
      sagaLabel: sagaLabel,
      director: director,
      cast: cast.map((c) => c.toDomain()).toList(growable: false),
      addedAt: addedAt,
      seasonsCount: domainSeasons.length,
      episodesCount: episodesCount,
      seasons: domainSeasons,
    );
  }
}

/// Wire-format DTO for one season inside a [RemoteSeriesDetailDto].
class RemoteSeasonDto {
  final int seasonNumber;
  final String? name;
  final String? posterUrl;
  final String? synopsis;
  final List<RemoteEpisodeDto> episodes;

  const RemoteSeasonDto({
    required this.seasonNumber,
    required this.episodes,
    this.name,
    this.posterUrl,
    this.synopsis,
  });

  factory RemoteSeasonDto.fromJson(Map<String, dynamic> json) =>
      RemoteSeasonDto(
        seasonNumber: json['season_number'] as int,
        name: json['name'] as String?,
        posterUrl: json['poster_url'] as String?,
        synopsis: json['synopsis'] as String?,
        episodes: (json['episodes'] as List)
            .cast<Map<String, dynamic>>()
            .map(RemoteEpisodeDto.fromJson)
            .toList(growable: false),
      );

  Season toDomain({
    required String seriesId,
    required AgeCategory ageCategory,
  }) {
    return Season(
      seasonNumber: seasonNumber,
      name: name,
      posterUrl: posterUrl,
      synopsis: synopsis,
      episodes: episodes
          .map(
            (e) => e.toDomain(
              seriesId: seriesId,
              seasonNumber: seasonNumber,
              ageCategory: ageCategory,
            ),
          )
          .toList(growable: false),
    );
  }
}

/// Wire-format DTO for one episode inside a [RemoteSeasonDto].
///
/// `seriesId`, `seasonNumber` and `ageCategory` are NOT on the wire — the
/// payload doesn't repeat them per episode. They are injected by the
/// parent [RemoteSeasonDto.toDomain] call.
class RemoteEpisodeDto {
  final String id;
  final int episodeNumber;
  final String title;
  final String? originalTitle;
  final String? synopsis;
  final int durationSeconds;
  final String? thumbUrl;
  final String? airedAt;
  final DateTime addedAt;

  const RemoteEpisodeDto({
    required this.id,
    required this.episodeNumber,
    required this.title,
    required this.durationSeconds,
    required this.addedAt,
    this.originalTitle,
    this.synopsis,
    this.thumbUrl,
    this.airedAt,
  });

  factory RemoteEpisodeDto.fromJson(Map<String, dynamic> json) =>
      RemoteEpisodeDto(
        id: json['id'] as String,
        episodeNumber: json['episode_number'] as int,
        title: json['title'] as String,
        originalTitle: json['original_title'] as String?,
        synopsis: json['synopsis'] as String?,
        durationSeconds: json['duration_seconds'] as int,
        thumbUrl: json['thumb_url'] as String?,
        airedAt: json['aired_at'] as String?,
        addedAt: DateTime.parse(json['added_at'] as String),
      );

  Episode toDomain({
    required String seriesId,
    required int seasonNumber,
    required AgeCategory ageCategory,
  }) {
    return Episode(
      id: id,
      seriesId: seriesId,
      seasonNumber: seasonNumber,
      episodeNumber: episodeNumber,
      title: title,
      originalTitle: originalTitle,
      synopsis: synopsis,
      duration: Duration(seconds: durationSeconds),
      thumbUrl: thumbUrl,
      airedAt: airedAt == null ? null : DateTime.parse(airedAt!),
      ageCategory: ageCategory,
      addedAt: addedAt,
    );
  }
}
