import 'package:dio/dio.dart';
import 'package:kidflix/core/application/dtos/age_category_wire.dart';
import 'package:kidflix/core/application/dtos/remote_profile.dto.dart';
import 'package:kidflix/core/domain/exceptions/cannot_clear_main_profile_pin.exception.dart';
import 'package:kidflix/core/domain/exceptions/cannot_delete_main_profile.exception.dart';
import 'package:kidflix/core/domain/exceptions/unknown_profile.exception.dart';
import 'package:kidflix/core/domain/model/profile.dart';
import 'package:kidflix/core/domain/services/profile_management.repository.dart';
import 'package:kidflix/infrastructure/http/error_code.dart';

/// HTTP implementation of [ProfileManagementRepository] backed by Dio.
///
/// Hits the `/profiles/*` endpoints documented in `API.md` § Profils, and
/// translates the documented HTTP error codes into Domain exceptions:
///
/// - `404` on any `/profiles/{id}/*` route → [UnknownProfileException]
/// - `422 cannot_clear_main_profile_pin` → [CannotClearMainProfilePinException]
/// - `422 cannot_delete_main_profile` → [CannotDeleteMainProfileException]
///
/// The required `Authorization: Bearer <jwt>` and `X-Device-Id: <uuid>`
/// headers are injected transparently by the `AuthInterceptor` registered on
/// `dioProvider` — this repository never touches headers explicitly.
///
/// Any other failure (network error, 5xx, malformed payload) is rethrown as
/// the original [DioException] for the application layer to surface as a
/// generic error. No retry policy is applied.
class DioProfileManagementRepository implements ProfileManagementRepository {
  final Dio _dio;

  DioProfileManagementRepository(this._dio);

  @override
  Future<Profile> create({
    required String name,
    required AgeCategory ageCategory,
    String? rawPin,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/profiles',
      data: {
        'name': name,
        'age_category': ageCategoryToWire(ageCategory),
        'raw_pin': ?rawPin,
      },
    );
    return RemoteProfileDto.fromJson(response.data!).toDomain();
  }

  @override
  Future<Profile> updateMetadata({
    required String id,
    required String name,
    required AgeCategory ageCategory,
  }) async {
    try {
      final response = await _dio.patch<Map<String, dynamic>>(
        '/profiles/$id',
        data: {
          'name': name,
          'age_category': ageCategoryToWire(ageCategory),
        },
      );
      return RemoteProfileDto.fromJson(response.data!).toDomain();
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        throw UnknownProfileException(id);
      }
      rethrow;
    }
  }

  @override
  Future<Profile> setPin({
    required String id,
    required String rawPin,
  }) async {
    try {
      final response = await _dio.put<Map<String, dynamic>>(
        '/profiles/$id/pin',
        data: {'raw_pin': rawPin},
      );
      return RemoteProfileDto.fromJson(response.data!).toDomain();
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        throw UnknownProfileException(id);
      }
      rethrow;
    }
  }

  @override
  Future<Profile> clearPin({required String id}) async {
    try {
      final response = await _dio.delete<Map<String, dynamic>>(
        '/profiles/$id/pin',
      );
      return RemoteProfileDto.fromJson(response.data!).toDomain();
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 422 &&
          readErrorCode(e.response) == 'cannot_clear_main_profile_pin') {
        throw CannotClearMainProfilePinException(id);
      }
      if (status == 404) {
        throw UnknownProfileException(id);
      }
      rethrow;
    }
  }

  @override
  Future<void> delete({required String id}) async {
    try {
      await _dio.delete<void>('/profiles/$id');
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 422 &&
          readErrorCode(e.response) == 'cannot_delete_main_profile') {
        throw CannotDeleteMainProfileException(id);
      }
      if (status == 404) {
        throw UnknownProfileException(id);
      }
      rethrow;
    }
  }
}
