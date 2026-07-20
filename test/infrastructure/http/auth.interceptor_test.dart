import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kidflix/core/domain/model/device.dart';
import 'package:kidflix/core/domain/model/session.dart';
import 'package:kidflix/infrastructure/http/auth.interceptor.dart';

void main() {
  group('AuthInterceptor', () {
    test('skips /auth/request-otp without adding any auth header', () async {
      final adapter = _FakeAdapter();
      final dio = _dio(adapter);
      dio.interceptors.add(
        AuthInterceptor(session: () => _session, profileId: () => 'ar'),
      );

      await dio.post<dynamic>('/auth/request-otp');

      expect(adapter.last.headers, isNot(contains('Authorization')));
      expect(adapter.last.headers, isNot(contains('X-Device-Id')));
      expect(adapter.last.headers, isNot(contains('X-Profile-Id')));
    });

    test('skips /auth/verify-otp without adding any auth header', () async {
      final adapter = _FakeAdapter();
      final dio = _dio(adapter);
      dio.interceptors.add(
        AuthInterceptor(session: () => _session, profileId: () => 'ar'),
      );

      await dio.post<dynamic>('/auth/verify-otp');

      expect(adapter.last.headers, isNot(contains('Authorization')));
      expect(adapter.last.headers, isNot(contains('X-Device-Id')));
      expect(adapter.last.headers, isNot(contains('X-Profile-Id')));
    });

    test(
      'GET /profiles bootstrap receives JWT + device but NOT X-Profile-Id',
      () async {
        final adapter = _FakeAdapter();
        final dio = _dio(adapter);
        dio.interceptors.add(
          AuthInterceptor(session: () => _session, profileId: () => 'ar'),
        );

        await dio.get<dynamic>('/profiles');

        expect(adapter.last.headers['Authorization'], 'Bearer eyJabc');
        expect(adapter.last.headers['X-Device-Id'], 'uuid-1');
        expect(adapter.last.headers, isNot(contains('X-Profile-Id')));
      },
    );

    test('POST /profiles receives all three headers', () async {
      final adapter = _FakeAdapter();
      final dio = _dio(adapter);
      dio.interceptors.add(
        AuthInterceptor(session: () => _session, profileId: () => 'papa'),
      );

      await dio.post<dynamic>('/profiles');

      expect(adapter.last.headers['Authorization'], 'Bearer eyJabc');
      expect(adapter.last.headers['X-Device-Id'], 'uuid-1');
      expect(adapter.last.headers['X-Profile-Id'], 'papa');
    });

    test(
      'PATCH /profiles/:id receives all three headers (path is not the bootstrap exemption)',
      () async {
        final adapter = _FakeAdapter();
        final dio = _dio(adapter);
        dio.interceptors.add(
          AuthInterceptor(session: () => _session, profileId: () => 'papa'),
        );

        await dio.patch<dynamic>('/profiles/ar');

        expect(adapter.last.headers['Authorization'], 'Bearer eyJabc');
        expect(adapter.last.headers['X-Device-Id'], 'uuid-1');
        expect(adapter.last.headers['X-Profile-Id'], 'papa');
      },
    );

    test('GET /movies (protected route) receives all three headers', () async {
      final adapter = _FakeAdapter();
      final dio = _dio(adapter);
      dio.interceptors.add(
        AuthInterceptor(session: () => _session, profileId: () => 'ar'),
      );

      await dio.get<dynamic>('/movies');

      expect(adapter.last.headers['Authorization'], 'Bearer eyJabc');
      expect(adapter.last.headers['X-Device-Id'], 'uuid-1');
      expect(adapter.last.headers['X-Profile-Id'], 'ar');
    });

    test(
      'lets the request through without any auth header when session is null',
      () async {
        final adapter = _FakeAdapter();
        final dio = _dio(adapter);
        dio.interceptors.add(
          AuthInterceptor(session: () => null, profileId: () => null),
        );

        await dio.get<dynamic>('/movies');

        expect(adapter.last.headers, isNot(contains('Authorization')));
        expect(adapter.last.headers, isNot(contains('X-Device-Id')));
        expect(adapter.last.headers, isNot(contains('X-Profile-Id')));
      },
    );

    test(
      'profile-id null but session present injects only JWT + device on protected routes',
      () async {
        final adapter = _FakeAdapter();
        final dio = _dio(adapter);
        dio.interceptors.add(
          AuthInterceptor(session: () => _session, profileId: () => null),
        );

        await dio.get<dynamic>('/movies');

        expect(adapter.last.headers['Authorization'], 'Bearer eyJabc');
        expect(adapter.last.headers['X-Device-Id'], 'uuid-1');
        expect(adapter.last.headers, isNot(contains('X-Profile-Id')));
      },
    );

    test('reflects profile-id changes between consecutive requests', () async {
      final adapter = _FakeAdapter();
      final dio = _dio(adapter);
      String? currentProfileId = 'ar';
      dio.interceptors.add(
        AuthInterceptor(
          session: () => _session,
          profileId: () => currentProfileId,
        ),
      );

      await dio.get<dynamic>('/movies');
      expect(adapter.requests[0].headers['X-Profile-Id'], 'ar');

      currentProfileId = 'ro';
      await dio.get<dynamic>('/movies');
      expect(adapter.requests[1].headers['X-Profile-Id'], 'ro');

      currentProfileId = null;
      await dio.get<dynamic>('/movies');
      expect(adapter.requests[2].headers, isNot(contains('X-Profile-Id')));
    });

    test('reflects session changes between consecutive requests', () async {
      final adapter = _FakeAdapter();
      final dio = _dio(adapter);
      Session? current;
      dio.interceptors.add(
        AuthInterceptor(session: () => current, profileId: () => null),
      );

      await dio.get<dynamic>('/profiles');
      expect(adapter.requests[0].headers, isNot(contains('Authorization')));

      current = _session;
      await dio.get<dynamic>('/profiles');
      expect(adapter.requests[1].headers['Authorization'], 'Bearer eyJabc');
      expect(adapter.requests[1].headers['X-Device-Id'], 'uuid-1');

      current = null;
      await dio.get<dynamic>('/profiles');
      expect(adapter.requests[2].headers, isNot(contains('Authorization')));
    });
  });

  group('AuthInterceptor — expired token detection', () {
    test('notifies onUnauthorized on 401 invalid_token', () async {
      var calls = 0;
      final dio = _dio(_unauthorizedAdapter());
      dio.interceptors.add(
        AuthInterceptor(
          session: () => _session,
          profileId: () => 'ar',
          onUnauthorized: () => calls++,
        ),
      );

      await expectLater(
        dio.get<dynamic>('/movies'),
        throwsA(isA<DioException>()),
      );
      expect(calls, 1);
    });

    test('forwards the original DioException to the caller', () async {
      final dio = _dio(_unauthorizedAdapter());
      dio.interceptors.add(
        AuthInterceptor(
          session: () => _session,
          profileId: () => 'ar',
          onUnauthorized: () {},
        ),
      );

      await expectLater(
        dio.get<dynamic>('/movies'),
        throwsA(
          isA<DioException>().having(
            (e) => e.response?.statusCode,
            'statusCode',
            401,
          ),
        ),
      );
    });

    test('ignores 401 invalid_otp on /auth/verify-otp', () async {
      var calls = 0;
      final adapter = _FakeAdapter(
        status: 401,
        body: {
          'error': {'code': 'invalid_otp'},
        },
      );
      final dio = _dio(adapter);
      dio.interceptors.add(
        AuthInterceptor(
          session: () => null,
          profileId: () => null,
          onUnauthorized: () => calls++,
        ),
      );

      await expectLater(
        dio.post<dynamic>('/auth/verify-otp'),
        throwsA(isA<DioException>()),
      );
      expect(calls, 0);
    });

    test('ignores a 401 carrying a different error code', () async {
      var calls = 0;
      final adapter = _FakeAdapter(
        status: 401,
        body: {
          'error': {'code': 'something_else'},
        },
      );
      final dio = _dio(adapter);
      dio.interceptors.add(
        AuthInterceptor(
          session: () => _session,
          profileId: () => 'ar',
          onUnauthorized: () => calls++,
        ),
      );

      await expectLater(
        dio.get<dynamic>('/movies'),
        throwsA(isA<DioException>()),
      );
      expect(calls, 0);
    });

    test('ignores non-401 failures', () async {
      var calls = 0;
      final adapter = _FakeAdapter(
        status: 403,
        body: {
          'error': {'code': 'forbidden_profile'},
        },
      );
      final dio = _dio(adapter);
      dio.interceptors.add(
        AuthInterceptor(
          session: () => _session,
          profileId: () => 'ar',
          onUnauthorized: () => calls++,
        ),
      );

      await expectLater(
        dio.get<dynamic>('/movies'),
        throwsA(isA<DioException>()),
      );
      expect(calls, 0);
    });

    test('stays inert when no onUnauthorized callback is wired', () async {
      final dio = _dio(_unauthorizedAdapter());
      dio.interceptors.add(
        AuthInterceptor(session: () => _session, profileId: () => 'ar'),
      );

      await expectLater(
        dio.get<dynamic>('/movies'),
        throwsA(isA<DioException>()),
      );
    });
  });
}

/// Adapter answering the documented `401 invalid_token` envelope.
_FakeAdapter _unauthorizedAdapter() => _FakeAdapter(
  status: 401,
  body: {
    'error': {'code': 'invalid_token'},
  },
);

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
  /// Defaults to `200` with an empty body. Pass [status] / [body] to make
  /// the adapter answer an error envelope instead (used by the
  /// `401 invalid_token` tests).
  _FakeAdapter({this.status = 200, this.body});

  final int status;
  final Object? body;
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
    if (body == null) {
      return ResponseBody.fromBytes(<int>[], status, headers: const {});
    }
    return ResponseBody.fromBytes(
      utf8.encode(json.encode(body)),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
