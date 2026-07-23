import 'package:flutter_test/flutter_test.dart';
import 'package:kidflix/core/application/dtos/catalog_row.dto.dart';
import 'package:kidflix/core/application/dtos/movie.dto.dart';
import 'package:kidflix/core/application/dtos/series.dto.dart';
import 'package:kidflix/core/application/remote/remote_catalog_codec.dart';

void main() {
  group('rows round-trip', () {
    test('a mixed row survives encode → decode', () {
      const row = CatalogRowDto(
        label: 'Récemment ajoutés',
        type: 'recentlyAdded',
        items: [
          MovieDto(
            id: 'm1',
            title: 'Vaiana',
            year: 2016,
            duration: Duration(hours: 1, minutes: 47),
            posterUrl: 'https://x/p.jpg',
            ageCategory: 'enfant',
          ),
          SeriesDto(
            id: 's1',
            title: 'Bluey',
            year: 2018,
            posterUrl: 'https://x/b.jpg',
            ageCategory: 'bebe',
            seasonsCount: 3,
            episodesCount: 60,
          ),
        ],
      );

      final decoded = RemoteCatalogCodec.decodeRows([
        RemoteCatalogCodec.encodeRow(row),
      ]).single;

      expect(decoded.label, equals('Récemment ajoutés'));
      expect(decoded.type, equals('recentlyAdded'));
      expect(decoded.items, hasLength(2));

      final movie = decoded.items[0] as MovieDto;
      expect(movie.id, equals('m1'));
      expect(movie.title, equals('Vaiana'));
      expect(movie.duration, equals(const Duration(hours: 1, minutes: 47)));
      expect(movie.ageCategory, equals('enfant'));

      final series = decoded.items[1] as SeriesDto;
      expect(series.id, equals('s1'));
      expect(series.seasonsCount, equals(3));
      expect(series.episodesCount, equals(60));
    });

    test('an unknown item kind is skipped, not fatal', () {
      // Forward compatibility with a host on a newer build that serves a
      // catalogue entry this build has no card for.
      final decoded = RemoteCatalogCodec.decodeRow({
        'label': 'x',
        'type': 'x',
        'items': [
          {'kind': 'podcast', 'id': 'p1', 'title': 'Ep'},
          {'kind': 'movie', 'id': 'm2', 'title': 'Cars', 'durationSeconds': 60},
        ],
      });

      expect(decoded.items, hasLength(1));
      expect(decoded.items.single.id, equals('m2'));
    });

    test('a non-list payload decodes to no rows', () {
      expect(RemoteCatalogCodec.decodeRows('nope'), isEmpty);
    });
  });

  group('movie detail round-trip', () {
    test('every field survives', () {
      const detail = MovieDetailDto(
        id: 'm7',
        title: 'Le Roi Lion',
        originalTitle: 'The Lion King',
        year: 1994,
        duration: Duration(hours: 1, minutes: 28),
        synopsis: 'Simba…',
        tagline: 'Sa destinée',
        posterUrl: 'https://x/poster.jpg',
        backdropUrl: 'https://x/back.jpg',
        logoUrl: 'https://x/logo.png',
        trailerUrl: 'https://x/trailer',
        ageCategory: 'enfant',
        genres: ['Animation', 'Aventure'],
        director: ['Roger Allers', 'Rob Minkoff'],
        topCast: [
          CastMemberDto(name: 'Matthew Broderick', role: 'Simba'),
        ],
      );

      final decoded = RemoteCatalogCodec.decodeMovieDetail(
        RemoteCatalogCodec.encodeMovieDetail(detail),
      );

      expect(decoded.id, equals('m7'));
      expect(decoded.originalTitle, equals('The Lion King'));
      expect(decoded.duration, equals(const Duration(hours: 1, minutes: 28)));
      expect(decoded.tagline, equals('Sa destinée'));
      expect(decoded.genres, equals(['Animation', 'Aventure']));
      expect(decoded.director, hasLength(2));
      expect(decoded.topCast.single.name, equals('Matthew Broderick'));
      expect(decoded.topCast.single.role, equals('Simba'));
    });

    test('optional fields tolerate absence', () {
      final decoded = RemoteCatalogCodec.decodeMovieDetail({
        'id': 'm8',
        'title': 'Minimal',
        'durationSeconds': 0,
      });

      expect(decoded.id, equals('m8'));
      expect(decoded.originalTitle, isNull);
      expect(decoded.genres, isEmpty);
      expect(decoded.topCast, isEmpty);
    });
  });
}
