import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kidflix/core/domain/model/watch_progress.dart';
import 'package:kidflix/infrastructure/watch_progress/dio.watch_progress.repository.dart';

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

ResponseBody _nullJsonResponse(int status) {
  final encoded = utf8.encode('null');
  return ResponseBody.fromBytes(
    encoded,
    status,
    headers: {
      Headers.contentTypeHeader: ['application/json; charset=utf-8'],
    },
  );
}

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

Map<String, dynamic> _progressJson({
  String profileId = 'p1',
  String movieId = 'm1',
  int positionSeconds = 1845,
  bool completed = false,
  String updatedAt = '2026-04-22T10:30:00Z',
}) => {
  'profile_id': profileId,
  'movie_id': movieId,
  'position_seconds': positionSeconds,
  'completed': completed,
  'updated_at': updatedAt,
};

void main() {
  group('DioWatchProgressRepository.findFor', () {
    test('issues GET on the correct path and parses a 200 body', () async {
      final adapter = _FakeAdapter(
        (_) => _jsonResponse(200, _progressJson()),
      );
      final repo = DioWatchProgressRepository(dio: _makeDio(adapter));

      final result = await repo.findFor(profileId: 'p1', movieId: 'm1');

      expect(result, isNotNull);
      expect(result!.profileId, 'p1');
      expect(result.movieId, 'm1');
      expect(result.positionSeconds, 1845);
      expect(result.completed, isFalse);
      expect(result.updatedAt, DateTime.utc(2026, 4, 22, 10, 30));
      expect(adapter.requests, hasLength(1));
      expect(adapter.requests.single.method, 'GET');
      expect(adapter.requests.single.path, '/profiles/p1/progress/m1');
    });

    test('returns null on 204 No Content without parsing body', () async {
      final adapter = _FakeAdapter((_) => _emptyResponse(204));
      final repo = DioWatchProgressRepository(dio: _makeDio(adapter));

      final result = await repo.findFor(profileId: 'p1', movieId: 'm1');

      expect(result, isNull);
    });

    test('returns null defensively when 200 carries a null body', () async {
      final adapter = _FakeAdapter((_) => _nullJsonResponse(200));
      final repo = DioWatchProgressRepository(dio: _makeDio(adapter));

      final result = await repo.findFor(profileId: 'p1', movieId: 'm1');

      expect(result, isNull);
    });

    test('rethrows DioException on 404', () async {
      final adapter = _FakeAdapter(
        (_) => _jsonResponse(404, {
          'error': {'code': 'not_found'},
        }),
      );
      final repo = DioWatchProgressRepository(dio: _makeDio(adapter));

      await expectLater(
        repo.findFor(profileId: 'p1', movieId: 'unknown'),
        throwsA(
          isA<DioException>().having(
            (e) => e.response?.statusCode,
            'statusCode',
            404,
          ),
        ),
      );
    });
  });

  group('DioWatchProgressRepository.save', () {
    test('issues PUT with the correct path and minimal body', () async {
      final adapter = _FakeAdapter(
        (_) => _jsonResponse(200, _progressJson(positionSeconds: 1900)),
      );
      final repo = DioWatchProgressRepository(dio: _makeDio(adapter));

      await repo.save(
        WatchProgress(
          profileId: 'p1',
          movieId: 'm1',
          positionSeconds: 1900,
          completed: false,
          updatedAt: DateTime.utc(2026, 4, 22, 10, 30, 10),
        ),
      );

      expect(adapter.requests, hasLength(1));
      final request = adapter.requests.single;
      expect(request.method, 'PUT');
      expect(request.path, '/profiles/p1/progress/m1');
      expect(request.data, {
        'position_seconds': 1900,
        'completed': false,
      });
    });

    test('PUT body omits path-only and server-stamped fields', () async {
      final adapter = _FakeAdapter((_) => _emptyResponse(200));
      final repo = DioWatchProgressRepository(dio: _makeDio(adapter));

      await repo.save(
        WatchProgress(
          profileId: 'p1',
          movieId: 'm1',
          positionSeconds: 100,
          completed: false,
          updatedAt: DateTime.utc(2026, 4, 22),
        ),
      );

      final body = adapter.requests.single.data as Map<String, dynamic>;
      expect(body.containsKey('profile_id'), isFalse);
      expect(body.containsKey('movie_id'), isFalse);
      expect(body.containsKey('updated_at'), isFalse);
    });

    test('completes successfully without parsing the response body', () async {
      final adapter = _FakeAdapter(
        (_) => _jsonResponse(200, {'unrelated': 'shape'}),
      );
      final repo = DioWatchProgressRepository(dio: _makeDio(adapter));

      await expectLater(
        repo.save(
          WatchProgress(
            profileId: 'p1',
            movieId: 'm1',
            positionSeconds: 200,
            completed: true,
            updatedAt: DateTime.utc(2026, 4, 22),
          ),
        ),
        completes,
      );
    });

    test('rethrows DioException on 500', () async {
      final adapter = _FakeAdapter((_) => _emptyResponse(500));
      final repo = DioWatchProgressRepository(dio: _makeDio(adapter));

      await expectLater(
        repo.save(
          WatchProgress(
            profileId: 'p1',
            movieId: 'm1',
            positionSeconds: 200,
            completed: false,
            updatedAt: DateTime.utc(2026, 4, 22),
          ),
        ),
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

  group('DioWatchProgressRepository.listForProfile', () {
    test('issues GET on the list path and returns parsed entries', () async {
      final adapter = _FakeAdapter(
        (_) => _jsonResponse(200, {
          'progress': [
            _progressJson(movieId: 'm1', positionSeconds: 100),
            _progressJson(movieId: 'm2', positionSeconds: 200, completed: true),
          ],
        }),
      );
      final repo = DioWatchProgressRepository(dio: _makeDio(adapter));

      final result = await repo.listForProfile('p1');

      expect(result, hasLength(2));
      expect(result[0].movieId, 'm1');
      expect(result[0].positionSeconds, 100);
      expect(result[0].completed, isFalse);
      expect(result[1].movieId, 'm2');
      expect(result[1].positionSeconds, 200);
      expect(result[1].completed, isTrue);
      expect(adapter.requests, hasLength(1));
      expect(adapter.requests.single.method, 'GET');
      expect(adapter.requests.single.path, '/profiles/p1/progress');
    });

    test('returns empty list when backend has none', () async {
      final adapter = _FakeAdapter(
        (_) => _jsonResponse(200, {'progress': <Map<String, dynamic>>[]}),
      );
      final repo = DioWatchProgressRepository(dio: _makeDio(adapter));

      final result = await repo.listForProfile('p1');

      expect(result, isEmpty);
    });

    test('rethrows DioException on 401', () async {
      final adapter = _FakeAdapter(
        (_) => _jsonResponse(401, {
          'error': {'code': 'invalid_token'},
        }),
      );
      final repo = DioWatchProgressRepository(dio: _makeDio(adapter));

      await expectLater(
        repo.listForProfile('p1'),
        throwsA(isA<DioException>()),
      );
    });
  });

  group('DioWatchProgressRepository auth headers', () {
    test('repo never sets Authorization explicitly', () async {
      final adapter = _FakeAdapter(
        (_) => _jsonResponse(200, _progressJson()),
      );
      final repo = DioWatchProgressRepository(dio: _makeDio(adapter));

      await repo.findFor(profileId: 'p1', movieId: 'm1');
      await repo.save(
        WatchProgress(
          profileId: 'p1',
          movieId: 'm1',
          positionSeconds: 100,
          completed: false,
          updatedAt: DateTime.utc(2026, 4, 22),
        ),
      );

      for (final request in adapter.requests) {
        expect(
          request.headers.containsKey('Authorization'),
          isFalse,
          reason: 'Auth header injection is the AuthInterceptor\'s job, '
              'not the repo\'s.',
        );
        expect(request.headers.containsKey('X-Device-Id'), isFalse);
      }
    });
  });
}
