import 'package:dio/dio.dart';
import 'package:kidflix/core/application/dtos/remote_wishlist_entry.dto.dart';
import 'package:kidflix/core/application/dtos/remote_wishlist_search_result.dto.dart';
import 'package:kidflix/core/domain/exceptions/wishlist_entry_already_exists.exception.dart';
import 'package:kidflix/core/domain/exceptions/wishlist_not_configured.exception.dart';
import 'package:kidflix/core/domain/model/wishlist_entry.dart';
import 'package:kidflix/core/domain/model/wishlist_search_result.dart';
import 'package:kidflix/core/domain/services/wishlist.repository.dart';
import 'package:kidflix/infrastructure/http/error_code.dart';

/// HTTP implementation of [WishlistRepository] backed by Dio.
///
/// Hits the endpoints documented in `WATCHARR_WISHLIST_FEATURE.md`:
///
/// * `GET    /wishlist`
/// * `GET    /wishlist/search?q=...`
/// * `POST   /wishlist`
/// * `PUT    /wishlist/{id}/status`
/// * `DELETE /wishlist/{id}`
///
/// The required `Authorization`, `X-Device-Id`, `X-Profile-Id` headers
/// are injected transparently by the `AuthInterceptor` registered on
/// `dioProvider`. The backend gates everything on `is_main` — non-main
/// callers get `403 main_profile_required`, surfaced here as a generic
/// [DioException] for the application layer to handle.
///
/// Two typed mappings are surfaced :
///
/// - `503 wishlist_not_configured` → [WishlistNotConfiguredException].
///   The UI renders a dedicated empty state rather than a generic
///   retry banner.
/// - `409 wishlist_entry_exists` (upstream `403 watched entry exists`
///   from Watcharr, normalised to a 409 by kidflix-api) →
///   [WishlistEntryAlreadyExistsException]. The UI shows a friendly
///   "déjà dans la liste" snackbar.
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

  @override
  Future<List<WishlistSearchResult>> search(String query) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/wishlist/search',
        queryParameters: {'q': query},
      );
      final items = (response.data!['items'] as List)
          .cast<Map<String, dynamic>>();
      return items
          .map(RemoteWishlistSearchResultDto.fromJson)
          .map((dto) => dto.toDomain())
          .toList(growable: false);
    } on DioException catch (e) {
      _rethrowTyped(e);
    }
  }

  @override
  Future<WishlistEntry> add({
    required int tmdbId,
    required WishlistItemKind kind,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/wishlist',
        data: {
          'tmdb_id': tmdbId,
          'kind': wishlistKindToWire(kind),
        },
      );
      return RemoteWishlistEntryDto.fromJson(response.data!).toDomain();
    } on DioException catch (e) {
      _rethrowTyped(e);
    }
  }

  /// Maps the few typed error codes the UI cares about. Anything else
  /// re-throws as-is (the original [DioException] bubbles up to the
  /// controller, which surfaces a generic snackbar).
  Never _rethrowTyped(DioException e) {
    final code = readErrorCode(e.response);
    if (e.response?.statusCode == 503 && code == 'wishlist_not_configured') {
      throw const WishlistNotConfiguredException();
    }
    if (e.response?.statusCode == 409 && code == 'wishlist_entry_exists') {
      throw const WishlistEntryAlreadyExistsException();
    }
    throw e;
  }
}
