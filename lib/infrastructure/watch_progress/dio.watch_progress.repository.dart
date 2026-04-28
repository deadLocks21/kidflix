import 'package:dio/dio.dart';
import 'package:kidflix/core/application/dtos/remote_watch_progress.dto.dart';
import 'package:kidflix/core/domain/model/watch_progress.dart';
import 'package:kidflix/core/domain/services/watch_progress.repository.dart';

/// HTTP implementation of [WatchProgressRepository] backed by Dio.
///
/// Hits the three endpoints documented in `API.md` § Progression de
/// lecture (`GET`, `PUT`, `GET liste`). [findFor] treats `204 No
/// Content` as `null` per the API contract, with a defensive fallback
/// on a `null` body in case the backend opts for `200` + null.
///
/// The required `Authorization: Bearer <jwt>` and `X-Device-Id: <uuid>`
/// headers are injected transparently by the `AuthInterceptor`
/// registered on `dioProvider` — this repository never touches headers
/// explicitly. No metier-level error mapping: any `4xx`/`5xx`/network
/// error surfaces as a generic [DioException] (same posture as
/// `DioCatalogRepository`).
class DioWatchProgressRepository implements WatchProgressRepository {
  final Dio _dio;

  DioWatchProgressRepository({required Dio dio}) : _dio = dio;

  @override
  Future<WatchProgress?> findFor({
    required String profileId,
    required String movieId,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/profiles/$profileId/progress/$movieId',
    );
    if (response.statusCode == 204 || response.data == null) return null;
    return RemoteWatchProgressDto.fromJson(response.data!).toDomain();
  }

  @override
  Future<void> save(WatchProgress progress) async {
    final dto = RemoteWatchProgressDto(
      profileId: progress.profileId,
      movieId: progress.movieId,
      positionSeconds: progress.positionSeconds,
      completed: progress.completed,
      updatedAt: progress.updatedAt,
    );
    await _dio.put<void>(
      '/profiles/${progress.profileId}/progress/${progress.movieId}',
      data: dto.toWireBody(),
    );
  }

  @override
  Future<List<WatchProgress>> listForProfile(String profileId) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/profiles/$profileId/progress',
    );
    final list = (response.data!['progress'] as List)
        .cast<Map<String, dynamic>>();
    return list
        .map(RemoteWatchProgressDto.fromJson)
        .map((d) => d.toDomain())
        .toList(growable: false);
  }
}
