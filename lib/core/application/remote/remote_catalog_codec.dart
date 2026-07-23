import 'package:kidflix/core/application/dtos/catalog_item.dto.dart';
import 'package:kidflix/core/application/dtos/catalog_row.dto.dart';
import 'package:kidflix/core/application/dtos/movie.dto.dart';
import 'package:kidflix/core/application/dtos/series.dto.dart';

/// Wire format for the catalogue a host serves to its remotes.
///
/// Lives here rather than as `toJson` on the DTOs on purpose: those are
/// UI-facing projections shared by every screen, and they should not
/// grow a serialisation concern that exists only for one feature. This
/// file owns the mapping in both directions and is the only thing to
/// update when the wire has to change.
abstract final class RemoteCatalogCodec {
  static Map<String, Object?> encodeRow(CatalogRowDto row) => {
    'label': row.label,
    'type': row.type,
    'items': [for (final item in row.items) encodeItem(item)],
  };

  static Map<String, Object?> encodeItem(CatalogItemDto item) => switch (item) {
    MovieDto() => {
      'kind': 'movie',
      'id': item.id,
      'title': item.title,
      'year': item.year,
      'durationSeconds': item.duration.inSeconds,
      'posterUrl': item.posterUrl,
      'ageCategory': item.ageCategory,
    },
    SeriesDto() => {
      'kind': 'series',
      'id': item.id,
      'title': item.title,
      'year': item.year,
      'posterUrl': item.posterUrl,
      'ageCategory': item.ageCategory,
      'seasonsCount': item.seasonsCount,
      'episodesCount': item.episodesCount,
    },
    // `CatalogItemDto` cannot be sealed (its subtypes live in separate
    // libraries), so a new variant would land here. Encoding it as a
    // movie would put a broken card on the remote; dropping it shows a
    // shorter row, which is at least honest.
    _ => const {},
  };

  static List<CatalogRowDto> decodeRows(Object? raw) => switch (raw) {
    final List rows => [
      for (final row in rows)
        if (row is Map) decodeRow(Map<String, Object?>.from(row)),
    ],
    _ => const [],
  };

  static CatalogRowDto decodeRow(Map<String, Object?> json) => CatalogRowDto(
    label: json['label'] is String ? json['label']! as String : '',
    type: json['type'] is String ? json['type']! as String : '',
    items: switch (json['items']) {
      final List raw => [
        for (final item in raw)
          if (item is Map)
            ?decodeItem(Map<String, Object?>.from(item)),
      ],
      _ => const [],
    },
  );

  static CatalogItemDto? decodeItem(Map<String, Object?> json) {
    final id = json['id'];
    final title = json['title'];
    if (id is! String || title is! String) return null;
    final year = (json['year'] as num?)?.toInt();
    final posterUrl = json['posterUrl'] is String
        ? json['posterUrl']! as String
        : null;
    final ageCategory = json['ageCategory'] is String
        ? json['ageCategory']! as String
        : '';
    return switch (json['kind']) {
      'series' => SeriesDto(
        id: id,
        title: title,
        year: year,
        posterUrl: posterUrl,
        ageCategory: ageCategory,
        seasonsCount: (json['seasonsCount'] as num?)?.toInt() ?? 0,
        episodesCount: (json['episodesCount'] as num?)?.toInt() ?? 0,
      ),
      'movie' => MovieDto(
        id: id,
        title: title,
        year: year,
        duration: Duration(
          seconds: (json['durationSeconds'] as num?)?.toInt() ?? 0,
        ),
        posterUrl: posterUrl,
        ageCategory: ageCategory,
      ),
      _ => null,
    };
  }

  static Map<String, Object?> encodeMovieDetail(MovieDetailDto movie) => {
    'id': movie.id,
    'title': movie.title,
    'originalTitle': movie.originalTitle,
    'year': movie.year,
    'durationSeconds': movie.duration.inSeconds,
    'synopsis': movie.synopsis,
    'tagline': movie.tagline,
    'posterUrl': movie.posterUrl,
    'backdropUrl': movie.backdropUrl,
    'logoUrl': movie.logoUrl,
    'trailerUrl': movie.trailerUrl,
    'ageCategory': movie.ageCategory,
    'genres': movie.genres,
    'director': movie.director,
    'topCast': [
      for (final member in movie.topCast)
        {
          'name': member.name,
          'role': member.role,
          'photoUrl': member.photoUrl,
        },
    ],
  };

  static MovieDetailDto decodeMovieDetail(Map<String, Object?> json) {
    String? str(String key) => json[key] is String ? json[key]! as String : null;
    List<String> strings(String key) => switch (json[key]) {
      final List raw => [
        for (final entry in raw)
          if (entry is String) entry,
      ],
      _ => const [],
    };
    return MovieDetailDto(
      id: str('id') ?? '',
      title: str('title') ?? '',
      originalTitle: str('originalTitle'),
      year: (json['year'] as num?)?.toInt(),
      duration: Duration(
        seconds: (json['durationSeconds'] as num?)?.toInt() ?? 0,
      ),
      synopsis: str('synopsis') ?? '',
      tagline: str('tagline'),
      posterUrl: str('posterUrl'),
      backdropUrl: str('backdropUrl'),
      logoUrl: str('logoUrl'),
      trailerUrl: str('trailerUrl'),
      ageCategory: str('ageCategory') ?? '',
      genres: strings('genres'),
      director: strings('director'),
      topCast: switch (json['topCast']) {
        final List raw => [
          for (final entry in raw)
            if (entry is Map)
              CastMemberDto(
                name: entry['name'] is String ? entry['name']! as String : '',
                role: entry['role'] is String ? entry['role']! as String : null,
                photoUrl: entry['photoUrl'] is String
                    ? entry['photoUrl']! as String
                    : null,
              ),
        ],
        _ => const [],
      },
    );
  }
}
