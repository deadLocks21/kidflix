import 'package:dio/dio.dart';
import 'package:kidflix/core/application/dtos/remote_seen.dto.dart';
import 'package:kidflix/core/domain/model/seen_mark.dart';
import 'package:kidflix/core/domain/services/seen.repository.dart';

/// HTTP implementation of [SeenRepository] backed by Dio.
///
/// Hits the endpoints documented in `SEEN_FEATURE.md`:
///
/// * `GET    /profiles/{p}/seen`
/// * `PUT    /profiles/{p}/seen/movies/{m}`
/// * `DELETE /profiles/{p}/seen/movies/{m}`
/// * `PUT    /profiles/{p}/seen`            (bulk — body `{ "movie_ids": [...] }`)
///
/// The required `Authorization`, `X-Device-Id`, `X-Profile-Id` headers
/// are injected transparently by the `AuthInterceptor` registered on
/// `dioProvider`. No metier-level error mapping: any 4xx / 5xx / network
/// error surfaces as a generic [DioException]. All mutation endpoints
/// reply `204 No Content` on success.
class DioSeenRepository implements SeenRepository {
  final Dio _dio;

  DioSeenRepository({required Dio dio}) : _dio = dio;

  @override
  Future<List<SeenMark>> listForProfile(String profileId) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/profiles/$profileId/seen',
    );
    final list = (response.data!['seen'] as List).cast<Map<String, dynamic>>();
    return list.map(seenMarkFromJson).toList(growable: false);
  }

  @override
  Future<void> markMovie({
    required String profileId,
    required String movieId,
  }) async {
    await _dio.put<void>('/profiles/$profileId/seen/movies/$movieId');
  }

  @override
  Future<void> unmarkMovie({
    required String profileId,
    required String movieId,
  }) async {
    await _dio.delete<void>('/profiles/$profileId/seen/movies/$movieId');
  }

  @override
  Future<void> markMovies({
    required String profileId,
    required List<String> movieIds,
  }) async {
    if (movieIds.isEmpty) return;
    await _dio.put<void>(
      '/profiles/$profileId/seen',
      data: {'movie_ids': movieIds},
    );
  }
}
