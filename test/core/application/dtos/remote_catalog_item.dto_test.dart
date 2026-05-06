import 'package:flutter_test/flutter_test.dart';
import 'package:kidflix/core/application/dtos/remote_catalog_item.dto.dart';
import 'package:kidflix/core/domain/model/media.dart';

Map<String, dynamic> _movieJson() => {
  'kind': 'movie',
  'id': 'nemo',
  'title': 'Le Monde de Nemo',
  'original_title': 'Finding Nemo',
  'year': 2003,
  'duration_seconds': 6000,
  'synopsis': 'Nemo, un poisson…',
  'tagline': null,
  'poster_url': null,
  'backdrop_url': null,
  'age_category': 'enfant',
  'genres': ['Animation'],
  'saga_id': null,
  'saga_label': null,
  'director': <String>['Andrew Stanton'],
  'cast': <Map<String, dynamic>>[],
  'added_at': '2026-04-22T10:00:00Z',
};

Map<String, dynamic> _seriesJson() => {
  'kind': 'series',
  'id': 'pingu',
  'title': 'Pingu',
  'original_title': 'Pingu',
  'year': 1990,
  'seasons_count': 3,
  'episodes_count': 12,
  'synopsis': '…',
  'tagline': null,
  'poster_url': null,
  'backdrop_url': null,
  'age_category': 'enfant',
  'genres': ['Animation'],
  'saga_id': null,
  'saga_label': null,
  'director': <String>[],
  'cast': <Map<String, dynamic>>[],
  'added_at': '2026-05-04T00:00:00Z',
};

void main() {
  group('catalogItemFromJson dispatch', () {
    test('dispatches "movie" → Movie', () {
      final item = catalogItemFromJson(_movieJson());
      expect(item, isA<Movie>());
      expect(item.id, 'nemo');
    });

    test('dispatches "series" → Series', () {
      final item = catalogItemFromJson(_seriesJson());
      expect(item, isA<Series>());
      expect(item.id, 'pingu');
      final series = item as Series;
      expect(series.seasonsCount, 3);
    });

    test('throws on unknown kind', () {
      final payload = _movieJson()..['kind'] = 'podcast';
      expect(
        () => catalogItemFromJson(payload),
        throwsA(isA<FormatException>()),
      );
    });

    test('throws on missing kind', () {
      final payload = Map<String, dynamic>.from(_movieJson())..remove('kind');
      expect(
        () => catalogItemFromJson(payload),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
