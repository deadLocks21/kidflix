import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kidflix/core/domain/model/device.dart';
import 'package:kidflix/core/domain/model/session.dart';
import 'package:kidflix/infrastructure/http/auth.interceptor.dart';

void main() {
  group('AuthInterceptor', () {
    test(
      'skips /auth/request-otp without adding Authorization or X-Device-Id',
      () async {
        final adapter = _FakeAdapter();
        final dio = _dio(adapter);
        dio.interceptors.add(AuthInterceptor(() => _session));

        await dio.post<dynamic>('/auth/request-otp');

        expect(adapter.last.headers, isNot(contains('Authorization')));
        expect(adapter.last.headers, isNot(contains('X-Device-Id')));
      },
    );

    test(
      'skips /auth/verify-otp without adding Authorization or X-Device-Id',
      () async {
        final adapter = _FakeAdapter();
        final dio = _dio(adapter);
        dio.interceptors.add(AuthInterceptor(() => _session));

        await dio.post<dynamic>('/auth/verify-otp');

        expect(adapter.last.headers, isNot(contains('Authorization')));
        expect(adapter.last.headers, isNot(contains('X-Device-Id')));
      },
    );

    test(
      'adds Bearer JWT and X-Device-Id headers when session is present',
      () async {
        final adapter = _FakeAdapter();
        final dio = _dio(adapter);
        dio.interceptors.add(AuthInterceptor(() => _session));

        await dio.get<dynamic>('/profiles/123');

        expect(adapter.last.headers['Authorization'], 'Bearer eyJabc');
        expect(adapter.last.headers['X-Device-Id'], 'uuid-1');
      },
    );

    test(
      'lets the request through without auth headers when session is null',
      () async {
        final adapter = _FakeAdapter();
        final dio = _dio(adapter);
        dio.interceptors.add(AuthInterceptor(() => null));

        await dio.get<dynamic>('/profiles/123');

        expect(adapter.last.headers, isNot(contains('Authorization')));
        expect(adapter.last.headers, isNot(contains('X-Device-Id')));
      },
    );

    test('reflects session changes between consecutive requests', () async {
      final adapter = _FakeAdapter();
      final dio = _dio(adapter);
      Session? current;
      dio.interceptors.add(AuthInterceptor(() => current));

      // 1st request — no session
      await dio.get<dynamic>('/profiles');
      expect(adapter.requests[0].headers, isNot(contains('Authorization')));

      // Login
      current = _session;
      await dio.get<dynamic>('/profiles');
      expect(adapter.requests[1].headers['Authorization'], 'Bearer eyJabc');
      expect(adapter.requests[1].headers['X-Device-Id'], 'uuid-1');

      // Logout
      current = null;
      await dio.get<dynamic>('/profiles');
      expect(adapter.requests[2].headers, isNot(contains('Authorization')));
    });
  });
}

Dio _dio(_FakeAdapter adapter) {
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

const Session _session = Session(
  jwt: 'eyJabc',
  device: Device(id: 'uuid-1', name: null),
  profiles: [],
);

class _CapturedRequest {
  _CapturedRequest({required this.path, required this.headers});

  final String path;
  final Map<String, dynamic> headers;
}

class _FakeAdapter implements HttpClientAdapter {
  final List<_CapturedRequest> requests = [];

  _CapturedRequest get last => requests.last;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(
      _CapturedRequest(
        path: options.path,
        headers: Map<String, dynamic>.from(options.headers),
      ),
    );
    return ResponseBody.fromBytes(
      <int>[],
      200,
      headers: const {},
    );
  }

  @override
  void close({bool force = false}) {}
}
