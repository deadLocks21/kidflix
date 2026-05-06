import 'package:dio/dio.dart';
import 'package:kidflix/core/application/dtos/remote_catalog_item.dto.dart';
import 'package:kidflix/core/domain/model/media.dart';
import 'package:kidflix/core/domain/services/catalog.repository.dart';

/// HTTP implementation of [CatalogRepository] backed by Dio.
///
/// Hits `GET /catalog` and `GET /catalog/search` per `API.md` § Catalogue.
/// The required `Authorization: Bearer <jwt>`, `X-Device-Id: <uuid>` and
/// `X-Profile-Id: <profile_id>` headers are injected transparently by the
/// `AuthInterceptor` registered on `dioProvider` — this repository never
/// touches headers explicitly.
///
/// The age filter is **server-side only**: the backend resolves the active
/// profile from the `X-Profile-Id` header and returns only items whose
/// `ageCategory == profile.ageCategory` (homepage) or `ageCategory ≤
/// profile.ageCategory` (search). The repository sends no age-related
/// query parameter.
///
/// Each item in the response is discriminated by a `kind` field
/// (`"movie"` | `"series"`) and parsed via [catalogItemFromJson] (which
/// dispatches to the corresponding [RemoteMovieDto] / `RemoteSeriesCatalogDto`).
///
/// No domain-specific exception is mapped: any failure (network error,
/// 4xx incl. `400 missing_profile_id`, 5xx, malformed payload) is
/// rethrown as the original [DioException] for the application layer to
/// surface as a generic error. No retry policy is applied.
class DioCatalogRepository implements CatalogRepository {
  final Dio _dio;

  DioCatalogRepository(this._dio);

  @override
  Future<List<CatalogItem>> listCatalog() async {
    final response = await _dio.get<Map<String, dynamic>>('/catalog');
    return _parseItems(response.data!);
  }

  @override
  Future<List<CatalogItem>> searchCatalog({required String query}) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/catalog/search',
      queryParameters: {'q': query},
    );
    return _parseItems(response.data!);
  }

  @override
  Future<List<CatalogItem>> listCatalogForProfile(String profileId) async {
    // Pre-set the X-Profile-Id header on this call. The AuthInterceptor
    // detects the override and forwards as-is instead of replacing with
    // currentProfileId — see auth.interceptor.dart.
    final response = await _dio.get<Map<String, dynamic>>(
      '/catalog',
      options: Options(headers: {'X-Profile-Id': profileId}),
    );
    return _parseItems(response.data!);
  }

  List<CatalogItem> _parseItems(Map<String, dynamic> body) {
    final raw = (body['items'] as List).cast<Map<String, dynamic>>();
    return raw.map(catalogItemFromJson).toList(growable: false);
  }
}
