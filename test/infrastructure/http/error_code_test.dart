import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kidflix/infrastructure/http/error_code.dart';

void main() {
  group('readErrorCode', () {
    test('reads error.code from a well-formed body', () {
      final response = _response({
        'error': {'code': 'invalid_otp', 'message': 'OTP code is invalid'},
      });

      expect(readErrorCode(response), 'invalid_otp');
    });

    test('returns null when error.code is absent', () {
      final response = _response({
        'error': {'message': 'Something happened'},
      });

      expect(readErrorCode(response), isNull);
    });

    test('returns null when body is a plain string', () {
      final response = _response('plain text not json');

      expect(readErrorCode(response), isNull);
    });

    test('returns null when response is null', () {
      expect(readErrorCode(null), isNull);
    });

    test('returns null when error.code is non-string', () {
      final response = _response({
        'error': {'code': 42},
      });

      expect(readErrorCode(response), isNull);
    });

    test('returns null when response.data is null', () {
      final response = _response(null);

      expect(readErrorCode(response), isNull);
    });

    test('returns null when error key is itself a string', () {
      final response = _response({'error': 'just a string'});

      expect(readErrorCode(response), isNull);
    });
  });
}

Response<dynamic> _response(dynamic data) {
  return Response<dynamic>(
    requestOptions: RequestOptions(path: '/'),
    data: data,
  );
}
