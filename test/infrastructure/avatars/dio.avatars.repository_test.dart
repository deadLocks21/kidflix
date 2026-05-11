import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kidflix/infrastructure/avatars/dio.avatars.repository.dart';

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

ResponseBody _jsonResponse(int status, Object body) => ResponseBody.fromBytes(
  utf8.encode(jsonEncode(body)),
  status,
  headers: {
    Headers.contentTypeHeader: ['application/json; charset=utf-8'],
  },
);

Dio _makeDio(_FakeAdapter adapter) {
  final dio = Dio(BaseOptions(baseUrl: 'http://test.local'));
  dio.httpClientAdapter = adapter;
  return dio;
}

void main() {
  group('DioAvatarsRepository.list', () {
    test('GET /avatars maps the envelope to a list of AvatarOption', () async {
      final adapter = _FakeAdapter(
        (_) => _jsonResponse(200, {
          'avatars': [
            {'id': 'cat-01', 'url': '/static/avatars/cat-01.svg'},
            {'id': 'fox-01', 'url': '/static/avatars/fox-01.svg'},
          ],
        }),
      );
      final repo = DioAvatarsRepository(_makeDio(adapter));

      final result = await repo.list();

      expect(result, hasLength(2));
      expect(result[0].id, 'cat-01');
      expect(result[0].url, '/static/avatars/cat-01.svg');
      expect(adapter.requests.single.method, 'GET');
      expect(adapter.requests.single.path, '/avatars');
    });

    test('parses an empty catalogue', () async {
      final adapter = _FakeAdapter(
        (_) => _jsonResponse(200, {'avatars': <Map<String, dynamic>>[]}),
      );
      final repo = DioAvatarsRepository(_makeDio(adapter));

      expect(await repo.list(), isEmpty);
    });

    test('rethrows DioException on 5xx', () async {
      final adapter = _FakeAdapter(
        (_) => ResponseBody.fromBytes(<int>[], 500, headers: const {}),
      );
      final repo = DioAvatarsRepository(_makeDio(adapter));

      await expectLater(repo.list(), throwsA(isA<DioException>()));
    });
  });
}
