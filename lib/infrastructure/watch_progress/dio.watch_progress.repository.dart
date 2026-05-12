import 'package:dio/dio.dart';
import 'package:kidflix/core/application/dtos/remote_watch_progress.dto.dart';
import 'package:kidflix/core/domain/model/watch_progress.dart';
import 'package:kidflix/core/domain/services/watch_progress.repository.dart';

/// HTTP implementation of [WatchProgressRepository] backed by Dio.
///
/// Hits the endpoints documented in `API.md` § Progression de lecture
/// and `DISMISS_FEATURE.md` :
///
/// * `GET    /profiles/{p}/progress/movies/{m}`
/// * `GET    /profiles/{p}/progress/episodes/{e}`
/// * `PUT    /profiles/{p}/progress/movies/{m}`
/// * `PUT    /profiles/{p}/progress/episodes/{e}`
/// * `GET    /profiles/{p}/progress`
/// * `POST   /profiles/{p}/progress/movies/{m}/dismiss`
/// * `DELETE /profiles/{p}/progress/movies/{m}/dismiss`
/// * `POST   /profiles/{p}/progress/episodes/{e}/dismiss`
/// * `DELETE /profiles/{p}/progress/episodes/{e}/dismiss`
///
/// `findForMovie` / `findForEpisode` treat `204` as `null` per the API
/// contract, with a defensive fallback on a `null` body if the backend
/// opts for `200` + null.
///
/// The required `Authorization`, `X-Device-Id`, `X-Profile-Id` headers
/// are injected transparently by the `AuthInterceptor` registered on
/// `dioProvider`. No metier-level error mapping: any 4xx / 5xx /
/// network error surfaces as a generic [DioException].
class DioWatchProgressRepository implements WatchProgressRepository {
  final Dio _dio;

  DioWatchProgressRepository({required Dio dio}) : _dio = dio;

  @override
  Future<MovieProgress?> findForMovie({
    required String profileId,
    required String movieId,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/profiles/$profileId/progress/movies/$movieId',
    );
    if (response.statusCode == 204 || response.data == null) return null;
    final progress = watchProgressFromJson(response.data!);
    if (progress is! MovieProgress) {
      throw FormatException(
        'Expected MovieProgress on /progress/movies/$movieId, got '
        '${progress.runtimeType}',
      );
    }
    return progress;
  }

  @override
  Future<EpisodeProgress?> findForEpisode({
    required String profileId,
    required String episodeId,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/profiles/$profileId/progress/episodes/$episodeId',
    );
    if (response.statusCode == 204 || response.data == null) return null;
    final progress = watchProgressFromJson(response.data!);
    if (progress is! EpisodeProgress) {
      throw FormatException(
        'Expected EpisodeProgress on /progress/episodes/$episodeId, got '
        '${progress.runtimeType}',
      );
    }
    return progress;
  }

  @override
  Future<void> save(WatchProgress progress) async {
    final body = watchProgressToWireBody(progress);
    switch (progress) {
      case MovieProgress(:final profileId, :final movieId):
        await _dio.put<void>(
          '/profiles/$profileId/progress/movies/$movieId',
          data: body,
        );
      case EpisodeProgress(:final profileId, :final episodeId):
        await _dio.put<void>(
          '/profiles/$profileId/progress/episodes/$episodeId',
          data: body,
        );
    }
  }

  @override
  Future<List<WatchProgress>> listForProfile(String profileId) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/profiles/$profileId/progress',
    );
    final list = (response.data!['progress'] as List)
        .cast<Map<String, dynamic>>();
    return list.map(watchProgressFromJson).toList(growable: false);
  }

  @override
  Future<void> dismissMovie({
    required String profileId,
    required String movieId,
  }) async {
    await _dio.post<void>(
      '/profiles/$profileId/progress/movies/$movieId/dismiss',
    );
  }

  @override
  Future<void> unDismissMovie({
    required String profileId,
    required String movieId,
  }) async {
    await _dio.delete<void>(
      '/profiles/$profileId/progress/movies/$movieId/dismiss',
    );
  }

  @override
  Future<void> dismissEpisode({
    required String profileId,
    required String episodeId,
  }) async {
    await _dio.post<void>(
      '/profiles/$profileId/progress/episodes/$episodeId/dismiss',
    );
  }

  @override
  Future<void> unDismissEpisode({
    required String profileId,
    required String episodeId,
  }) async {
    await _dio.delete<void>(
      '/profiles/$profileId/progress/episodes/$episodeId/dismiss',
    );
  }
}
