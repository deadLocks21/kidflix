import 'package:dio/dio.dart';
import 'package:kidflix/core/application/dtos/remote_session.dto.dart';
import 'package:kidflix/core/domain/exceptions/invalid_otp.exception.dart';
import 'package:kidflix/core/domain/exceptions/otp_expired.exception.dart';
import 'package:kidflix/core/domain/exceptions/unknown_phone_number.exception.dart';
import 'package:kidflix/core/domain/model/device.dart';
import 'package:kidflix/core/domain/model/otp_code.dart';
import 'package:kidflix/core/domain/model/phone_number.dart';
import 'package:kidflix/core/domain/model/session.dart';
import 'package:kidflix/core/domain/services/auth.repository.dart';
import 'package:kidflix/infrastructure/http/error_code.dart';

/// HTTP implementation of [AuthRepository] backed by Dio.
///
/// Hits `POST /auth/request-otp` and `POST /auth/verify-otp` per the
/// contract documented in `API.md` § Auth, and translates the documented
/// HTTP error codes into Domain exceptions:
///
/// - `404 unknown_phone_number` → [UnknownPhoneNumberException]
/// - `401 invalid_otp`          → [InvalidOtpException]
/// - `410 otp_expired`          → [OtpExpiredException]
///
/// Any other failure (network error, 5xx, 429, malformed body) is rethrown
/// as a [DioException] for the application layer to surface as a generic
/// error. No retry policy is applied at this stage.
class DioAuthRepository implements AuthRepository {
  final Dio _dio;

  DioAuthRepository(this._dio);

  @override
  Future<DateTime> requestOtp(PhoneNumber phoneNumber) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/auth/request-otp',
        data: {'phone_number': phoneNumber.e164},
      );
      final expiresAtRaw = response.data!['expires_at'] as String;
      return DateTime.parse(expiresAtRaw);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404 &&
          readErrorCode(e.response) == 'unknown_phone_number') {
        throw UnknownPhoneNumberException(phoneNumber);
      }
      rethrow;
    }
  }

  @override
  Future<Session> verifyOtp(
    PhoneNumber phoneNumber,
    OtpCode code,
    Device device,
  ) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/auth/verify-otp',
        data: {
          'phone_number': phoneNumber.e164,
          'code': code.value,
          'device_id': device.id,
          if (device.name != null) 'device_name': device.name,
        },
      );
      return RemoteSessionDto.fromJson(response.data!).toDomain();
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      final code = readErrorCode(e.response);
      if (status == 401 && code == 'invalid_otp') {
        throw const InvalidOtpException();
      }
      if (status == 410 && code == 'otp_expired') {
        throw const OtpExpiredException();
      }
      if (status == 404 && code == 'unknown_phone_number') {
        throw UnknownPhoneNumberException(phoneNumber);
      }
      rethrow;
    }
  }
}
