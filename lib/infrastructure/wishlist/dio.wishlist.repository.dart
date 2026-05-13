import 'package:dio/dio.dart';
import 'package:kidflix/core/application/dtos/remote_wishlist_entry.dto.dart';
import 'package:kidflix/core/domain/exceptions/wishlist_not_configured.exception.dart';
import 'package:kidflix/core/domain/model/wishlist_entry.dart';
import 'package:kidflix/core/domain/services/wishlist.repository.dart';
import 'package:kidflix/infrastructure/http/error_code.dart';

/// HTTP implementation of [WishlistRepository] backed by Dio.
///
/// Hits the endpoints documented in `WATCHARR_WISHLIST_FEATURE.md`:
///
/// * `GET    /wishlist`
/// * `PUT    /wishlist/{id}/status`
/// * `DELETE /wishlist/{id}`
///
/// The required `Authorization`, `X-Device-Id`, `X-Profile-Id` headers
/// are injected transparently by the `AuthInterceptor` registered on
/// `dioProvider`. The backend gates everything on `is_main` — non-main
/// callers get `403 main_profile_required`, surfaced here as a generic
/// [DioException] for the application layer to handle.
///
/// One typed mapping only: a `503 wishlist_not_configured` is
/// translated to [WishlistNotConfiguredException] so the UI can render
/// a dedicated empty state ("active la feature avec un compte
/// Watcharr") rather than a generic retry banner.
class DioWishlistRepository implements WishlistRepository {
  final Dio _dio;

  DioWishlistRepository({required Dio dio}) : _dio = dio;

  @override
  Future<List<WishlistEntry>> list() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/wishlist');
      final list = (response.data!['items'] as List)
          .cast<Map<String, dynamic>>();
      return list
          .map(RemoteWishlistEntryDto.fromJson)
          .map((dto) => dto.toDomain())
          .toList(growable: false);
    } on DioException catch (e) {
      _rethrowTyped(e);
    }
  }

  @override
  Future<WishlistEntry> updateStatus({
    required int watcharrId,
    required WatchedStatus status,
  }) async {
    try {
      final response = await _dio.put<Map<String, dynamic>>(
        '/wishlist/$watcharrId/status',
        data: {'status': watchedStatusToWire(status)},
      );
      return RemoteWishlistEntryDto.fromJson(response.data!).toDomain();
    } on DioException catch (e) {
      _rethrowTyped(e);
    }
  }

  @override
  Future<void> remove(int watcharrId) async {
    try {
      await _dio.delete<void>('/wishlist/$watcharrId');
    } on DioException catch (e) {
      _rethrowTyped(e);
    }
  }

  /// Maps the few typed error codes the UI cares about. Anything else
  /// re-throws as-is (the surrounding `rethrow` in the caller bubbles
  /// the original [DioException] up to the controller, which surfaces
  /// a snackbar).
  Never _rethrowTyped(DioException e) {
    if (e.response?.statusCode == 503 &&
        readErrorCode(e.response) == 'wishlist_not_configured') {
      throw const WishlistNotConfiguredException();
    }
    throw e;
  }
}
