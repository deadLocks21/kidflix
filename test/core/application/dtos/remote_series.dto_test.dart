import 'package:flutter_test/flutter_test.dart';
import 'package:kidflix/core/application/dtos/remote_series.dto.dart';
import 'package:kidflix/core/domain/model/profile.dart';

Map<String, dynamic> _pinguCatalogJson() => {
  'kind': 'series',
  'id': 'pingu',
  'title': 'Pingu',
  'original_title': 'Pingu',
  'year': 1990,
  'seasons_count': 6,
  'episodes_count': 105,
  'synopsis': "Les aventures d'un manchot espiègle…",
  'tagline': null,
  'poster_url': 'https://image.tmdb.org/t/p/original/poster.jpg',
  'backdrop_url': 'https://image.tmdb.org/t/p/original/backdrop.jpg',
  'logo_url': 'https://image.tmdb.org/t/p/original/pingu_catalog_logo.png',
  'trailer_url':
      'plugin://plugin.video.youtube/play/?video_id=PinguTrailer1',
  'age_category': 'enfant',
  'genres': ['Animation', 'Familial'],
  'saga_id': null,
  'saga_label': null,
  'director': <String>[],
  'cast': <Map<String, dynamic>>[],
  'added_at': '2026-05-04T00:00:00Z',
};

Map<String, dynamic> _pinguDetailJson() => {
  'id': 'pingu',
  'title': 'Pingu',
  'original_title': 'Pingu',
  'year': 1990,
  'synopsis': "Les aventures d'un manchot…",
  'tagline': null,
  'poster_url': 'https://image.tmdb.org/t/p/original/poster.jpg',
  'backdrop_url': 'https://image.tmdb.org/t/p/original/backdrop.jpg',
  'logo_url': 'https://image.tmdb.org/t/p/original/pingu_detail_logo.png',
  'trailer_url':
      'plugin://plugin.video.youtube/play/?video_id=PinguTrailer2',
  'age_category': 'enfant',
  'genres': ['Animation', 'Familial'],
  'director': <String>[],
  'cast': <Map<String, dynamic>>[],
  'saga_id': null,
  'saga_label': null,
  'added_at': '2026-05-04T00:00:00Z',
  'seasons': [
    {
      'season_number': 0,
      'name': 'Specials',
      'poster_url': null,
      'synopsis': null,
      'episodes': [
        {
          'id': 'ep-special-1',
          'episode_number': 1,
          'title': "Pingu's Lost Christmas",
          'original_title': null,
          'synopsis': '...',
          'duration_seconds': 1500,
          'thumb_url': 'https://image.tmdb.org/special.jpg',
          'aired_at': '1996-12-25',
          'added_at': '2026-05-04T00:00:00Z',
        },
      ],
    },
    {
      'season_number': 1,
      'name': null,
      'poster_url': 'https://image.tmdb.org/s1.jpg',
      'synopsis': null,
      'episodes': [
        {
          'id': 'ep-s1e1',
          'episode_number': 1,
          'title': 'Hello',
          'original_title': null,
          'synopsis': 'Pingu rencontre…',
          'duration_seconds': 300,
          'thumb_url': 'https://image.tmdb.org/s1e1.jpg',
          'aired_at': '1990-04-13',
          'added_at': '2026-05-04T00:00:00Z',
        },
        {
          'id': 'ep-s1e2',
          'episode_number': 2,
          'title': 'Pingu plays',
          'original_title': null,
          'synopsis': null,
          'duration_seconds': 300,
          'thumb_url': null,
          'aired_at': null,
          'added_at': '2026-05-04T00:00:00Z',
        },
      ],
    },
  ],
};

void main() {
  group('RemoteSeriesCatalogDto.fromJson + toDomain', () {
    test('parses a catalog series with empty seasons', () {
      final domain =
          RemoteSeriesCatalogDto.fromJson(_pinguCatalogJson()).toDomain();

      expect(domain.id, 'pingu');
      expect(domain.title, 'Pingu');
      expect(domain.year, 1990);
      expect(domain.seasonsCount, 6);
      expect(domain.episodesCount, 105);
      expect(domain.ageCategory, AgeCategory.enfant);
      expect(domain.genres, ['Animation', 'Familial']);
      expect(domain.seasons, isEmpty);
      expect(
        domain.trailerUrl,
        'plugin://plugin.video.youtube/play/?video_id=PinguTrailer1',
      );
    });

    test('trailer_url is null when absent from the catalog payload', () {
      final payload = _pinguCatalogJson()..remove('trailer_url');
      final domain = RemoteSeriesCatalogDto.fromJson(payload).toDomain();
      expect(domain.trailerUrl, isNull);
    });

    test('logo_url is projected through to the catalog projection', () {
      final domain =
          RemoteSeriesCatalogDto.fromJson(_pinguCatalogJson()).toDomain();
      expect(
        domain.logoUrl,
        'https://image.tmdb.org/t/p/original/pingu_catalog_logo.png',
      );
    });

    test('throws on unknown age_category', () {
      final payload = _pinguCatalogJson()..['age_category'] = 'martian';
      expect(
        () => RemoteSeriesCatalogDto.fromJson(payload),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('RemoteSeriesDetailDto.fromJson + toDomain', () {
    test('parses Pingu detail with Specials and Season 1', () {
      final domain =
          RemoteSeriesDetailDto.fromJson(_pinguDetailJson()).toDomain();

      expect(domain.id, 'pingu');
      expect(domain.seasons.length, 2);
      expect(domain.seasonsCount, 2);
      expect(domain.episodesCount, 3);

      final specials = domain.seasons[0];
      expect(specials.seasonNumber, 0);
      expect(specials.name, 'Specials');
      expect(specials.episodes.length, 1);

      final s1 = domain.seasons[1];
      expect(s1.seasonNumber, 1);
      expect(s1.episodes.length, 2);
    });

    test('injects seriesId, seasonNumber and ageCategory into each episode',
        () {
      final domain =
          RemoteSeriesDetailDto.fromJson(_pinguDetailJson()).toDomain();
      for (final season in domain.seasons) {
        for (final ep in season.episodes) {
          expect(ep.seriesId, 'pingu');
          expect(ep.seasonNumber, season.seasonNumber);
          expect(ep.ageCategory, AgeCategory.enfant);
        }
      }
    });

    test('parses aired_at as a DateTime when present, null when absent', () {
      final domain =
          RemoteSeriesDetailDto.fromJson(_pinguDetailJson()).toDomain();
      final s1e1 = domain.seasons
          .firstWhere((s) => s.seasonNumber == 1)
          .episodes
          .firstWhere((e) => e.episodeNumber == 1);
      final s1e2 = domain.seasons
          .firstWhere((s) => s.seasonNumber == 1)
          .episodes
          .firstWhere((e) => e.episodeNumber == 2);
      expect(s1e1.airedAt, DateTime.parse('1990-04-13'));
      expect(s1e2.airedAt, isNull);
    });

    test('episode duration_seconds projects to a Duration', () {
      final domain =
          RemoteSeriesDetailDto.fromJson(_pinguDetailJson()).toDomain();
      final special = domain.seasons[0].episodes[0];
      expect(special.duration, const Duration(seconds: 1500));
    });

    test('trailer_url is projected through to the domain Series', () {
      final domain =
          RemoteSeriesDetailDto.fromJson(_pinguDetailJson()).toDomain();
      expect(
        domain.trailerUrl,
        'plugin://plugin.video.youtube/play/?video_id=PinguTrailer2',
      );
    });

    test('logo_url is projected through to the domain Series', () {
      final domain =
          RemoteSeriesDetailDto.fromJson(_pinguDetailJson()).toDomain();
      expect(
        domain.logoUrl,
        'https://image.tmdb.org/t/p/original/pingu_detail_logo.png',
      );
    });
  });
}
