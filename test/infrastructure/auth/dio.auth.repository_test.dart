import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kidflix/core/domain/exceptions/invalid_otp.exception.dart';
import 'package:kidflix/core/domain/exceptions/otp_expired.exception.dart';
import 'package:kidflix/core/domain/exceptions/unknown_phone_number.exception.dart';
import 'package:kidflix/core/domain/model/device.dart';
import 'package:kidflix/core/domain/model/otp_code.dart';
import 'package:kidflix/core/domain/model/phone_number.dart';
import 'package:kidflix/infrastructure/auth/dio.auth.repository.dart';

/// In-memory [HttpClientAdapter] that replays a canned response for each
/// request and records the requests it sees so tests can assert on the body.
///
/// Avoids pulling a mock library — Dio is wired against a real adapter, so
/// the request/response objects, exception types and JSON encoding all
/// behave exactly as in production.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this._respond);

  final ResponseBody Function(RequestOptions options, _CapturedRequest captured)
  _respond;

  final List<_CapturedRequest> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final bodyBytes = requestStream == null
        ? Uint8List(0)
        : await _collectBytes(requestStream);
    final captured = _CapturedRequest(
      path: options.path,
      method: options.method,
      bodyBytes: bodyBytes,
    );
    requests.add(captured);
    return _respond(options, captured);
  }

  @override
  void close({bool force = false}) {}

  Future<Uint8List> _collectBytes(Stream<Uint8List> stream) async {
    final chunks = <Uint8List>[];
    var total = 0;
    await for (final chunk in stream) {
      chunks.add(chunk);
      total += chunk.length;
    }
    final out = Uint8List(total);
    var offset = 0;
    for (final chunk in chunks) {
      out.setRange(offset, offset + chunk.length, chunk);
      offset += chunk.length;
    }
    return out;
  }
}

class _CapturedRequest {
  _CapturedRequest({
    required this.path,
    required this.method,
    required this.bodyBytes,
  });

  final String path;
  final String method;
  final Uint8List bodyBytes;

  Map<String, dynamic> get bodyJson =>
      jsonDecode(utf8.decode(bodyBytes)) as Map<String, dynamic>;
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

ResponseBody _rawResponse(int status, String raw) {
  return ResponseBody.fromBytes(
    utf8.encode(raw),
    status,
    headers: {
      Headers.contentTypeHeader: ['text/plain; charset=utf-8'],
    },
  );
}

ResponseBody _emptyResponse(int status) {
  return ResponseBody.fromBytes(<int>[], status, headers: const {});
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

void main() {
  group('DioAuthRepository.requestOtp', () {
    test('returns the parsed expires_at on 200', () async {
      final adapter = _FakeAdapter(
        (_, _) => _jsonResponse(200, {'expires_at': '2026-04-27T15:00:00Z'}),
      );
      final repo = DioAuthRepository(_makeDio(adapter));

      final expiresAt = await repo.requestOtp(PhoneNumber.parse('0612345678'));

      expect(expiresAt, DateTime.parse('2026-04-27T15:00:00Z'));
      expect(adapter.requests, hasLength(1));
      expect(adapter.requests.single.path, '/auth/request-otp');
      expect(adapter.requests.single.method, 'POST');
      expect(adapter.requests.single.bodyJson, {
        'phone_number': '+33612345678',
      });
    });

    test('maps 404 unknown_phone_number to UnknownPhoneNumberException',
        () async {
      final adapter = _FakeAdapter(
        (_, _) => _jsonResponse(404, {
          'error': {'code': 'unknown_phone_number'},
        }),
      );
      final repo = DioAuthRepository(_makeDio(adapter));

      await expectLater(
        repo.requestOtp(PhoneNumber.parse('0699999999')),
        throwsA(
          isA<UnknownPhoneNumberException>().having(
            (e) => e.phoneNumber.e164,
            'phoneNumber.e164',
            '+33699999999',
          ),
        ),
      );
    });

    test('rethrows DioException on 429 rate_limited', () async {
      final adapter = _FakeAdapter(
        (_, _) =>
            _jsonResponse(429, {'error': {'code': 'rate_limited'}}),
      );
      final repo = DioAuthRepository(_makeDio(adapter));

      await expectLater(
        repo.requestOtp(PhoneNumber.parse('0612345678')),
        throwsA(
          isA<DioException>().having(
            (e) => e.response?.statusCode,
            'response.statusCode',
            429,
          ),
        ),
      );
    });

    test('rethrows DioException on 500', () async {
      final adapter = _FakeAdapter((_, _) => _emptyResponse(500));
      final repo = DioAuthRepository(_makeDio(adapter));

      await expectLater(
        repo.requestOtp(PhoneNumber.parse('0612345678')),
        throwsA(
          isA<DioException>().having(
            (e) => e.response?.statusCode,
            'response.statusCode',
            500,
          ),
        ),
      );
    });
  });

  group('DioAuthRepository.verifyOtp', () {
    Map<String, dynamic> profileJson({
      required String id,
      required String name,
      required String ageCategory,
      String? pinHash,
      String? avatarUrl,
      required bool isMain,
    }) => {
      'id': id,
      'name': name,
      'age_category': ageCategory,
      'pin_hash': pinHash,
      'avatar_url': avatarUrl,
      'is_main': isMain,
    };

    test('returns Session with Device sourced from the JSON response',
        () async {
      final adapter = _FakeAdapter(
        (_, _) => _jsonResponse(200, {
          'jwt': 'eyJabc',
          'device': {
            'id': '9b2-uuid',
            'name': 'iPhone backend-normalized',
          },
          'profiles': [
            profileJson(
              id: 'papa',
              name: 'Papa',
              ageCategory: 'adulte',
              pinHash: r'$2b$12$X',
              isMain: true,
            ),
          ],
        }),
      );
      final repo = DioAuthRepository(_makeDio(adapter));

      final session = await repo.verifyOtp(
        PhoneNumber.parse('0612345678'),
        OtpCode.parse('123456'),
        const Device(id: '9b2-uuid', name: 'iPhone client-side'),
      );

      expect(session.jwt, 'eyJabc');
      expect(
        session.device,
        const Device(id: '9b2-uuid', name: 'iPhone backend-normalized'),
        reason: 'Device must come from response, not the parameter',
      );
      expect(session.profiles, hasLength(1));
      expect(session.profiles.single.id, 'papa');
      expect(session.profiles.single.hasPin, isTrue);
    });

    test('omits device_name from request body when device.name is null',
        () async {
      final adapter = _FakeAdapter(
        (_, _) => _jsonResponse(200, {
          'jwt': 'jwt',
          'device': {'id': 'abc', 'name': null},
          'profiles': <Map<String, dynamic>>[],
        }),
      );
      final repo = DioAuthRepository(_makeDio(adapter));

      await repo.verifyOtp(
        PhoneNumber.parse('0612345678'),
        OtpCode.parse('123456'),
        const Device(id: 'abc'),
      );

      final body = adapter.requests.single.bodyJson;
      expect(body.containsKey('phone_number'), isTrue);
      expect(body.containsKey('code'), isTrue);
      expect(body.containsKey('device_id'), isTrue);
      expect(
        body.containsKey('device_name'),
        isFalse,
        reason: 'device_name must be omitted when null',
      );
    });

    test('maps 401 invalid_otp to InvalidOtpException', () async {
      final adapter = _FakeAdapter(
        (_, _) =>
            _jsonResponse(401, {'error': {'code': 'invalid_otp'}}),
      );
      final repo = DioAuthRepository(_makeDio(adapter));

      await expectLater(
        repo.verifyOtp(
          PhoneNumber.parse('0612345678'),
          OtpCode.parse('123456'),
          const Device(id: 'abc'),
        ),
        throwsA(isA<InvalidOtpException>()),
      );
    });

    test('maps 410 otp_expired to OtpExpiredException', () async {
      final adapter = _FakeAdapter(
        (_, _) =>
            _jsonResponse(410, {'error': {'code': 'otp_expired'}}),
      );
      final repo = DioAuthRepository(_makeDio(adapter));

      await expectLater(
        repo.verifyOtp(
          PhoneNumber.parse('0612345678'),
          OtpCode.parse('123456'),
          const Device(id: 'abc'),
        ),
        throwsA(isA<OtpExpiredException>()),
      );
    });

    test('maps 404 unknown_phone_number to UnknownPhoneNumberException',
        () async {
      final adapter = _FakeAdapter(
        (_, _) => _jsonResponse(404, {
          'error': {'code': 'unknown_phone_number'},
        }),
      );
      final repo = DioAuthRepository(_makeDio(adapter));

      await expectLater(
        repo.verifyOtp(
          PhoneNumber.parse('0699999999'),
          OtpCode.parse('123456'),
          const Device(id: 'abc'),
        ),
        throwsA(
          isA<UnknownPhoneNumberException>().having(
            (e) => e.phoneNumber.e164,
            'phoneNumber.e164',
            '+33699999999',
          ),
        ),
      );
    });

    test('rethrows DioException on 500', () async {
      final adapter = _FakeAdapter((_, _) => _emptyResponse(500));
      final repo = DioAuthRepository(_makeDio(adapter));

      await expectLater(
        repo.verifyOtp(
          PhoneNumber.parse('0612345678'),
          OtpCode.parse('123456'),
          const Device(id: 'abc'),
        ),
        throwsA(
          isA<DioException>().having(
            (e) => e.response?.statusCode,
            'response.statusCode',
            500,
          ),
        ),
      );
    });

    test(
      'survives a malformed (non-JSON) error body — rethrows DioException, '
      'not _CastError',
      () async {
        final adapter = _FakeAdapter(
          (_, _) => _rawResponse(401, 'plain text not json'),
        );
        final repo = DioAuthRepository(_makeDio(adapter));

        await expectLater(
          repo.verifyOtp(
            PhoneNumber.parse('0612345678'),
            OtpCode.parse('123456'),
            const Device(id: 'abc'),
          ),
          throwsA(isA<DioException>()),
        );
      },
    );
  });

  group('DioAuthRepository.fetchProfiles', () {
    Map<String, dynamic> profileJson({
      required String id,
      required String name,
      required String ageCategory,
      String? pinHash,
      String? avatarUrl,
      required bool isMain,
    }) => {
      'id': id,
      'name': name,
      'age_category': ageCategory,
      'pin_hash': pinHash,
      'avatar_url': avatarUrl,
      'is_main': isMain,
    };

    test('targets GET /profiles with no body and no query parameter',
        () async {
      final adapter = _FakeAdapter(
        (_, _) => _jsonResponse(200, {'profiles': <Map<String, dynamic>>[]}),
      );
      final repo = DioAuthRepository(_makeDio(adapter));

      await repo.fetchProfiles();

      expect(adapter.requests, hasLength(1));
      expect(adapter.requests.single.method, 'GET');
      expect(adapter.requests.single.path, '/profiles');
      expect(
        adapter.requests.single.bodyBytes,
        isEmpty,
        reason: 'GET /profiles must have no body',
      );
    });

    test('parses the profiles envelope and preserves order', () async {
      final adapter = _FakeAdapter(
        (_, _) => _jsonResponse(200, {
          'profiles': [
            profileJson(
              id: 'papa',
              name: 'Papa',
              ageCategory: 'adulte',
              pinHash: r'$2b$12$abc',
              isMain: true,
            ),
            profileJson(
              id: 'ar',
              name: 'Ar',
              ageCategory: 'enfant',
              isMain: false,
            ),
          ],
        }),
      );
      final repo = DioAuthRepository(_makeDio(adapter));

      final profiles = await repo.fetchProfiles();

      expect(profiles, hasLength(2));
      expect(profiles[0].id, 'papa');
      expect(profiles[0].isMain, isTrue);
      expect(profiles[0].pinHash, r'$2b$12$abc');
      expect(profiles[1].id, 'ar');
      expect(profiles[1].isMain, isFalse);
      expect(profiles[1].pinHash, isNull);
    });

    test('returns an empty list when the backend has none', () async {
      final adapter = _FakeAdapter(
        (_, _) => _jsonResponse(200, {'profiles': <Map<String, dynamic>>[]}),
      );
      final repo = DioAuthRepository(_makeDio(adapter));

      expect(await repo.fetchProfiles(), isEmpty);
    });

    test('rethrows DioException on 5xx', () async {
      final adapter = _FakeAdapter((_, _) => _emptyResponse(500));
      final repo = DioAuthRepository(_makeDio(adapter));

      await expectLater(
        repo.fetchProfiles(),
        throwsA(
          isA<DioException>().having(
            (e) => e.response?.statusCode,
            'response.statusCode',
            500,
          ),
        ),
      );
    });
  });
}
