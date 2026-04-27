import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kidflix/core/domain/exceptions/cannot_clear_main_profile_pin.exception.dart';
import 'package:kidflix/core/domain/exceptions/cannot_delete_main_profile.exception.dart';
import 'package:kidflix/core/domain/exceptions/unknown_profile.exception.dart';
import 'package:kidflix/core/domain/model/profile.dart';
import 'package:kidflix/infrastructure/profile_management/dio.profile_management.repository.dart';

class _CapturedRequest {
  _CapturedRequest({
    required this.path,
    required this.method,
    required this.bodyBytes,
  });

  final String path;
  final String method;
  final Uint8List bodyBytes;

  Map<String, dynamic>? get bodyJson {
    if (bodyBytes.isEmpty) return null;
    return jsonDecode(utf8.decode(bodyBytes)) as Map<String, dynamic>;
  }
}

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

ResponseBody _jsonResponse(int status, Object body) => ResponseBody.fromBytes(
  utf8.encode(jsonEncode(body)),
  status,
  headers: {
    Headers.contentTypeHeader: ['application/json; charset=utf-8'],
  },
);

ResponseBody _rawResponse(int status, String raw) => ResponseBody.fromBytes(
  utf8.encode(raw),
  status,
  headers: {
    Headers.contentTypeHeader: ['text/plain; charset=utf-8'],
  },
);

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

Map<String, dynamic> _profilePayload({
  String id = 'new-uuid',
  String name = 'Léa',
  String ageCategory = 'enfant',
  String? pinHash,
  String? avatarUrl,
  bool isMain = false,
}) => {
  'id': id,
  'name': name,
  'age_category': ageCategory,
  'pin_hash': pinHash,
  'avatar_url': avatarUrl,
  'is_main': isMain,
};

void main() {
  group('DioProfileManagementRepository.create', () {
    test('posts the body and returns the parsed profile', () async {
      final adapter = _FakeAdapter(
        (_, _) => _jsonResponse(
          200,
          _profilePayload(id: 'new-uuid', name: 'Léa'),
        ),
      );
      final repo = DioProfileManagementRepository(_makeDio(adapter));

      final created = await repo.create(
        name: 'Léa',
        ageCategory: AgeCategory.enfant,
        rawPin: '1234',
      );

      expect(created.id, 'new-uuid');
      expect(created.name, 'Léa');
      expect(created.ageCategory, AgeCategory.enfant);
      expect(created.isMain, isFalse);
      expect(adapter.requests.single.method, 'POST');
      expect(adapter.requests.single.path, '/profiles');
      expect(adapter.requests.single.bodyJson, {
        'name': 'Léa',
        'age_category': 'enfant',
        'raw_pin': '1234',
      });
    });

    test('omits raw_pin when rawPin is null', () async {
      final adapter = _FakeAdapter((_, _) => _jsonResponse(200, _profilePayload()));
      final repo = DioProfileManagementRepository(_makeDio(adapter));

      await repo.create(
        name: 'Léa',
        ageCategory: AgeCategory.enfant,
      );

      final body = adapter.requests.single.bodyJson!;
      expect(body.containsKey('raw_pin'), isFalse);
      expect(body, {'name': 'Léa', 'age_category': 'enfant'});
    });

    test('serializes jeune_adulte in snake_case', () async {
      final adapter = _FakeAdapter(
        (_, _) => _jsonResponse(
          200,
          _profilePayload(ageCategory: 'jeune_adulte'),
        ),
      );
      final repo = DioProfileManagementRepository(_makeDio(adapter));

      await repo.create(
        name: 'Sky',
        ageCategory: AgeCategory.jeuneAdulte,
      );

      expect(
        adapter.requests.single.bodyJson!['age_category'],
        'jeune_adulte',
      );
    });

    test('rethrows DioException on network failure', () async {
      final adapter = _FakeAdapter((_, _) => _emptyResponse(500));
      final repo = DioProfileManagementRepository(_makeDio(adapter));

      await expectLater(
        repo.create(name: 'X', ageCategory: AgeCategory.enfant),
        throwsA(isA<DioException>()),
      );
    });
  });

  group('DioProfileManagementRepository.updateMetadata', () {
    test('PATCH /profiles/{id} returns the parsed profile', () async {
      final adapter = _FakeAdapter(
        (_, _) => _jsonResponse(
          200,
          _profilePayload(id: 'ar', name: 'Arthur', ageCategory: 'ado'),
        ),
      );
      final repo = DioProfileManagementRepository(_makeDio(adapter));

      final updated = await repo.updateMetadata(
        id: 'ar',
        name: 'Arthur',
        ageCategory: AgeCategory.ado,
      );

      expect(updated.id, 'ar');
      expect(updated.name, 'Arthur');
      expect(updated.ageCategory, AgeCategory.ado);
      expect(adapter.requests.single.method, 'PATCH');
      expect(adapter.requests.single.path, '/profiles/ar');
      expect(adapter.requests.single.bodyJson, {
        'name': 'Arthur',
        'age_category': 'ado',
      });
    });

    test('maps 404 to UnknownProfileException', () async {
      final adapter = _FakeAdapter((_, _) => _emptyResponse(404));
      final repo = DioProfileManagementRepository(_makeDio(adapter));

      await expectLater(
        repo.updateMetadata(
          id: 'ghost',
          name: 'X',
          ageCategory: AgeCategory.enfant,
        ),
        throwsA(
          isA<UnknownProfileException>().having(
            (e) => e.profileId,
            'profileId',
            'ghost',
          ),
        ),
      );
    });
  });

  group('DioProfileManagementRepository.setPin', () {
    test('PUT /profiles/{id}/pin returns the parsed profile', () async {
      final adapter = _FakeAdapter(
        (_, _) => _jsonResponse(
          200,
          _profilePayload(id: 'ar', pinHash: r'$2b$12$abc'),
        ),
      );
      final repo = DioProfileManagementRepository(_makeDio(adapter));

      final updated = await repo.setPin(id: 'ar', rawPin: '9999');

      expect(updated.id, 'ar');
      expect(updated.pinHash, r'$2b$12$abc');
      expect(adapter.requests.single.method, 'PUT');
      expect(adapter.requests.single.path, '/profiles/ar/pin');
      expect(adapter.requests.single.bodyJson, {'raw_pin': '9999'});
    });

    test('maps 404 to UnknownProfileException', () async {
      final adapter = _FakeAdapter((_, _) => _emptyResponse(404));
      final repo = DioProfileManagementRepository(_makeDio(adapter));

      await expectLater(
        repo.setPin(id: 'ghost', rawPin: '1234'),
        throwsA(
          isA<UnknownProfileException>().having(
            (e) => e.profileId,
            'profileId',
            'ghost',
          ),
        ),
      );
    });
  });

  group('DioProfileManagementRepository.clearPin', () {
    test('DELETE /profiles/{id}/pin returns the cleared profile', () async {
      final adapter = _FakeAdapter(
        (_, _) => _jsonResponse(
          200,
          _profilePayload(id: 'ar'),
        ),
      );
      final repo = DioProfileManagementRepository(_makeDio(adapter));

      final updated = await repo.clearPin(id: 'ar');

      expect(updated.id, 'ar');
      expect(updated.pinHash, isNull);
      expect(adapter.requests.single.method, 'DELETE');
      expect(adapter.requests.single.path, '/profiles/ar/pin');
    });

    test('maps 422 cannot_clear_main_profile_pin', () async {
      final adapter = _FakeAdapter(
        (_, _) => _jsonResponse(422, {
          'error': {'code': 'cannot_clear_main_profile_pin'},
        }),
      );
      final repo = DioProfileManagementRepository(_makeDio(adapter));

      await expectLater(
        repo.clearPin(id: 'papa'),
        throwsA(
          isA<CannotClearMainProfilePinException>().having(
            (e) => e.profileId,
            'profileId',
            'papa',
          ),
        ),
      );
    });

    test('maps 404 to UnknownProfileException', () async {
      final adapter = _FakeAdapter((_, _) => _emptyResponse(404));
      final repo = DioProfileManagementRepository(_makeDio(adapter));

      await expectLater(
        repo.clearPin(id: 'ghost'),
        throwsA(isA<UnknownProfileException>()),
      );
    });

    test('rethrows DioException on 422 with non-matching error.code', () async {
      final adapter = _FakeAdapter(
        (_, _) => _jsonResponse(422, {
          'error': {'code': 'unrelated_constraint'},
        }),
      );
      final repo = DioProfileManagementRepository(_makeDio(adapter));

      await expectLater(
        repo.clearPin(id: 'ar'),
        throwsA(isA<DioException>()),
      );
    });

    test('rethrows DioException on malformed 422 body', () async {
      final adapter = _FakeAdapter((_, _) => _rawResponse(422, 'plain text'));
      final repo = DioProfileManagementRepository(_makeDio(adapter));

      await expectLater(
        repo.clearPin(id: 'ar'),
        throwsA(isA<DioException>()),
      );
    });
  });

  group('DioProfileManagementRepository.delete', () {
    test('DELETE /profiles/{id} completes silently on 204', () async {
      final adapter = _FakeAdapter((_, _) => _emptyResponse(204));
      final repo = DioProfileManagementRepository(_makeDio(adapter));

      await repo.delete(id: 'ar');

      expect(adapter.requests.single.method, 'DELETE');
      expect(adapter.requests.single.path, '/profiles/ar');
    });

    test('maps 422 cannot_delete_main_profile', () async {
      final adapter = _FakeAdapter(
        (_, _) => _jsonResponse(422, {
          'error': {'code': 'cannot_delete_main_profile'},
        }),
      );
      final repo = DioProfileManagementRepository(_makeDio(adapter));

      await expectLater(
        repo.delete(id: 'papa'),
        throwsA(
          isA<CannotDeleteMainProfileException>().having(
            (e) => e.profileId,
            'profileId',
            'papa',
          ),
        ),
      );
    });

    test('maps 404 to UnknownProfileException', () async {
      final adapter = _FakeAdapter((_, _) => _emptyResponse(404));
      final repo = DioProfileManagementRepository(_makeDio(adapter));

      await expectLater(
        repo.delete(id: 'ghost'),
        throwsA(isA<UnknownProfileException>()),
      );
    });

    test('rethrows DioException on malformed 422 body', () async {
      final adapter = _FakeAdapter((_, _) => _rawResponse(422, 'plain text'));
      final repo = DioProfileManagementRepository(_makeDio(adapter));

      await expectLater(
        repo.delete(id: 'ar'),
        throwsA(isA<DioException>()),
      );
    });

    test('rethrows DioException on 5xx', () async {
      final adapter = _FakeAdapter((_, _) => _emptyResponse(500));
      final repo = DioProfileManagementRepository(_makeDio(adapter));

      await expectLater(
        repo.delete(id: 'ar'),
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
