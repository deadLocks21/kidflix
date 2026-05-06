import 'package:dio/dio.dart';
import 'package:kidflix/core/application/dtos/remote_series.dto.dart';
import 'package:kidflix/core/domain/model/media.dart';
import 'package:kidflix/core/domain/services/series.repository.dart';

/// HTTP implementation of [SeriesRepository] backed by Dio.
///
/// Hits `GET /series/{seriesId}` per `API.md` § Détail d'une série.
/// The required `Authorization`, `X-Device-Id`, `X-Profile-Id` headers
/// are injected transparently by the `AuthInterceptor` registered on
/// `dioProvider`.
///
/// Errors (4xx incl. `403 forbidden_age_category` and `404 not_found`,
/// 5xx, network) surface as generic [DioException] for the application
/// layer to handle. No metier-level mapping.
class DioSeriesRepository implements SeriesRepository {
  final Dio _dio;

  DioSeriesRepository(this._dio);

  @override
  Future<Series> findById(String seriesId) async {
    final response = await _dio.get<Map<String, dynamic>>('/series/$seriesId');
    return RemoteSeriesDetailDto.fromJson(response.data!).toDomain();
  }

  @override
  Future<Series> findByIdForProfile(String seriesId, String profileId) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/series/$seriesId',
      options: Options(headers: {'X-Profile-Id': profileId}),
    );
    return RemoteSeriesDetailDto.fromJson(response.data!).toDomain();
  }
}
