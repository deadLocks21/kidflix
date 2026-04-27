import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kidflix/core/domain/model/profile.dart';
import 'package:kidflix/infrastructure/catalog/dio.catalog.repository.dart';

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
  final dio = Dio(
    BaseOptions(
      baseUrl: 'http://test.local',
      contentType: 'application/json',
      responseType: ResponseType.json,
    ),
  );
  dio.httpClientAdapter = adapter;
  return dio;
}

Map<String, dynamic> _movieJson({
  required String id,
  required String title,
  String ageCategory = 'enfant',
  int durationSeconds = 6000,
  String addedAt = '2026-04-22T10:00:00Z',
}) => {
  'id': id,
  'title': title,
  'original_title': null,
  'year': 2020,
  'duration_seconds': durationSeconds,
  'synopsis': '...',
  'tagline': null,
  'poster_url': null,
  'backdrop_url': null,
  'age_category': ageCategory,
  'genres': <String>['Familial'],
  'saga_id': null,
  'saga_label': null,
  'director': <String>['Director'],
  'cast': <Map<String, dynamic>>[],
  'added_at': addedAt,
};

void main() {
  group('DioCatalogRepository.listMoviesFor', () {
    test('issues GET /movies with age_category param and parses envelope',
        () async {
      final adapter = _FakeAdapter(
        (_) => _jsonResponse(200, {
          'movies': [
            _movieJson(id: 'm1', title: 'Movie 1'),
            _movieJson(id: 'm2', title: 'Movie 2'),
          ],
        }),
      );
      final repo = DioCatalogRepository(_makeDio(adapter));

      final movies = await repo.listMoviesFor(AgeCategory.enfant);

      expect(movies, hasLength(2));
      expect(movies[0].id, 'm1');
      expect(movies[1].id, 'm2');
      expect(adapter.requests, hasLength(1));
      expect(adapter.requests.single.path, '/movies');
      expect(adapter.requests.single.method, 'GET');
      expect(
        adapter.requests.single.queryParameters,
        {'age_category': 'enfant'},
      );
    });

    test('preserves backend order (no client-side sort)', () async {
      final adapter = _FakeAdapter(
        (_) => _jsonResponse(200, {
          'movies': [
            _movieJson(id: 'z', title: 'Z'),
            _movieJson(id: 'a', title: 'A'),
            _movieJson(id: 'm', title: 'M'),
          ],
        }),
      );
      final repo = DioCatalogRepository(_makeDio(adapter));

      final movies = await repo.listMoviesFor(AgeCategory.enfant);

      expect(movies.map((m) => m.id).toList(), ['z', 'a', 'm']);
    });

    test('returns empty list when backend has none', () async {
      final adapter = _FakeAdapter(
        (_) => _jsonResponse(200, {'movies': <Map<String, dynamic>>[]}),
      );
      final repo = DioCatalogRepository(_makeDio(adapter));

      final movies = await repo.listMoviesFor(AgeCategory.bebe);

      expect(movies, isEmpty);
    });

    test('serializes jeune_adulte in snake_case on the wire', () async {
      final adapter = _FakeAdapter(
        (_) => _jsonResponse(200, {'movies': <Map<String, dynamic>>[]}),
      );
      final repo = DioCatalogRepository(_makeDio(adapter));

      await repo.listMoviesFor(AgeCategory.jeuneAdulte);

      expect(
        adapter.requests.single.queryParameters,
        {'age_category': 'jeune_adulte'},
      );
    });

    test('rethrows DioException on 401', () async {
      final adapter = _FakeAdapter(
        (_) => _jsonResponse(401, {
          'error': {'code': 'invalid_token'},
        }),
      );
      final repo = DioCatalogRepository(_makeDio(adapter));

      await expectLater(
        repo.listMoviesFor(AgeCategory.enfant),
        throwsA(
          isA<DioException>().having(
            (e) => e.response?.statusCode,
            'statusCode',
            401,
          ),
        ),
      );
    });

    test('rethrows DioException on 500', () async {
      final adapter = _FakeAdapter((_) => _emptyResponse(500));
      final repo = DioCatalogRepository(_makeDio(adapter));

      await expectLater(
        repo.listMoviesFor(AgeCategory.enfant),
        throwsA(
          isA<DioException>().having(
            (e) => e.response?.statusCode,
            'statusCode',
            500,
          ),
        ),
      );
    });
  });

  group('DioCatalogRepository.searchMovies', () {
    test('issues GET /movies/search with q and up_to_age_category params',
        () async {
      final adapter = _FakeAdapter(
        (_) => _jsonResponse(200, {
          'movies': [_movieJson(id: 'asterix', title: 'Astérix')],
        }),
      );
      final repo = DioCatalogRepository(_makeDio(adapter));

      final movies = await repo.searchMovies(
        query: 'astérix',
        upToAgeCategory: AgeCategory.enfant,
      );

      expect(movies, hasLength(1));
      expect(movies.single.id, 'asterix');
      expect(adapter.requests.single.path, '/movies/search');
      expect(adapter.requests.single.method, 'GET');
      expect(adapter.requests.single.queryParameters, {
        'q': 'astérix',
        'up_to_age_category': 'enfant',
      });
    });

    test('passes the query verbatim — no trim, no lowercase, no accent strip',
        () async {
      final adapter = _FakeAdapter(
        (_) => _jsonResponse(200, {'movies': <Map<String, dynamic>>[]}),
      );
      final repo = DioCatalogRepository(_makeDio(adapter));

      await repo.searchMovies(
        query: '  ASTÉRIX  ',
        upToAgeCategory: AgeCategory.enfant,
      );

      expect(
        adapter.requests.single.queryParameters['q'],
        '  ASTÉRIX  ',
      );
    });

    test('forwards an empty query without bail-out', () async {
      final adapter = _FakeAdapter(
        (_) => _jsonResponse(200, {'movies': <Map<String, dynamic>>[]}),
      );
      final repo = DioCatalogRepository(_makeDio(adapter));

      final result = await repo.searchMovies(
        query: '',
        upToAgeCategory: AgeCategory.enfant,
      );

      expect(result, isEmpty);
      expect(adapter.requests, hasLength(1));
      expect(adapter.requests.single.queryParameters['q'], '');
    });

    test('serializes jeune_adulte in snake_case on the wire', () async {
      final adapter = _FakeAdapter(
        (_) => _jsonResponse(200, {'movies': <Map<String, dynamic>>[]}),
      );
      final repo = DioCatalogRepository(_makeDio(adapter));

      await repo.searchMovies(
        query: 'inception',
        upToAgeCategory: AgeCategory.jeuneAdulte,
      );

      expect(
        adapter.requests.single.queryParameters['up_to_age_category'],
        'jeune_adulte',
      );
    });

    test('rethrows DioException on 401', () async {
      final adapter = _FakeAdapter(
        (_) => _jsonResponse(401, {
          'error': {'code': 'invalid_token'},
        }),
      );
      final repo = DioCatalogRepository(_makeDio(adapter));

      await expectLater(
        repo.searchMovies(
          query: 'x',
          upToAgeCategory: AgeCategory.enfant,
        ),
        throwsA(isA<DioException>()),
      );
    });
  });
}
