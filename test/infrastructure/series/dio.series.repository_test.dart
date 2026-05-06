import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kidflix/infrastructure/series/dio.series.repository.dart';

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this._respond);

  final ResponseBody Function(RequestOptions options) _respond;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return _respond(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _jsonResponse(int status, Object body) {
  final encoded = utf8.encode(jsonEncode(body));
  return ResponseBody.fromBytes(
    encoded,
    status,
    headers: {
      Headers.contentTypeHeader: ['application/json; charset=utf-8'],
    },
  );
}

ResponseBody _emptyResponse(int status) =>
    ResponseBody.fromBytes(<int>[], status, headers: const {});

Dio _makeDio(_FakeAdapter adapter) {
  final dio = Dio(BaseOptions(baseUrl: 'http://test.local'));
  dio.httpClientAdapter = adapter;
  return dio;
}

Map<String, dynamic> _seriesDetailJson({String id = 'pingu'}) => {
  'id': id,
  'title': 'Pingu',
  'original_title': 'Pingu',
  'year': 1990,
  'synopsis': "Les aventures d'un manchot…",
  'tagline': null,
  'poster_url': null,
  'backdrop_url': null,
  'age_category': 'enfant',
  'genres': ['Animation', 'Familial'],
  'director': <String>[],
  'cast': <Map<String, dynamic>>[],
  'saga_id': null,
  'saga_label': null,
  'added_at': '2026-05-04T00:00:00Z',
  'seasons': [
    {
      'season_number': 1,
      'name': null,
      'poster_url': null,
      'synopsis': null,
      'episodes': [
        {
          'id': 'ep-s1e1',
          'episode_number': 1,
          'title': 'Hello',
          'original_title': null,
          'synopsis': null,
          'duration_seconds': 300,
          'thumb_url': null,
          'aired_at': '1990-04-13',
          'added_at': '2026-05-04T00:00:00Z',
        },
      ],
    },
  ],
};

void main() {
  group('DioSeriesRepository.findById', () {
    test('issues GET /series/{id} and parses the detail payload', () async {
      final adapter = _FakeAdapter(
        (_) => _jsonResponse(200, _seriesDetailJson()),
      );
      final repo = DioSeriesRepository(_makeDio(adapter));

      final series = await repo.findById('pingu');

      expect(adapter.requests.single.method, 'GET');
      expect(adapter.requests.single.path, '/series/pingu');
      expect(series.id, 'pingu');
      expect(series.seasons, hasLength(1));
      expect(series.seasons.single.episodes, hasLength(1));
    });

    test('rethrows DioException on 404 not_found', () async {
      final adapter = _FakeAdapter(
        (_) => _jsonResponse(404, {
          'error': {'code': 'not_found'},
        }),
      );
      final repo = DioSeriesRepository(_makeDio(adapter));

      await expectLater(
        repo.findById('ghost'),
        throwsA(
          isA<DioException>().having(
            (e) => e.response?.statusCode,
            'statusCode',
            404,
          ),
        ),
      );
    });

    test('rethrows DioException on 403 forbidden_age_category', () async {
      final adapter = _FakeAdapter(
        (_) => _jsonResponse(403, {
          'error': {'code': 'forbidden_age_category'},
        }),
      );
      final repo = DioSeriesRepository(_makeDio(adapter));

      await expectLater(
        repo.findById('out-of-scope'),
        throwsA(
          isA<DioException>().having(
            (e) => e.response?.statusCode,
            'statusCode',
            403,
          ),
        ),
      );
    });

    test('rethrows DioException on 5xx', () async {
      final adapter = _FakeAdapter((_) => _emptyResponse(502));
      final repo = DioSeriesRepository(_makeDio(adapter));

      await expectLater(
        repo.findById('any'),
        throwsA(
          isA<DioException>().having(
            (e) => e.response?.statusCode,
            'statusCode',
            502,
          ),
        ),
      );
    });
  });
}
