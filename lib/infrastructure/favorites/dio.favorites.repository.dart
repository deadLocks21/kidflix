import 'package:dio/dio.dart';
import 'package:kidflix/core/application/dtos/remote_favorite.dto.dart';
import 'package:kidflix/core/domain/model/favorite.dart';
import 'package:kidflix/core/domain/services/favorites.repository.dart';

/// HTTP implementation of [FavoritesRepository] backed by Dio.
///
/// Hits the endpoints documented in `FAVORITES_FEATURE.md`:
///
/// * `GET    /profiles/{p}/favorites`
/// * `PUT    /profiles/{p}/favorites/movies/{m}`
/// * `DELETE /profiles/{p}/favorites/movies/{m}`
/// * `PUT    /profiles/{p}/favorites/series/{s}`
/// * `DELETE /profiles/{p}/favorites/series/{s}`
///
/// The required `Authorization`, `X-Device-Id`, `X-Profile-Id` headers
/// are injected transparently by the `AuthInterceptor` registered on
/// `dioProvider`. No metier-level error mapping: any 4xx / 5xx /
/// network error surfaces as a generic [DioException]. All mutation
/// endpoints reply `204 No Content` on success.
class DioFavoritesRepository implements FavoritesRepository {
  final Dio _dio;

  DioFavoritesRepository({required Dio dio}) : _dio = dio;

  @override
  Future<List<Favorite>> listForProfile(String profileId) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/profiles/$profileId/favorites',
    );
    final list = (response.data!['favorites'] as List)
        .cast<Map<String, dynamic>>();
    return list.map(favoriteFromJson).toList(growable: false);
  }

  @override
  Future<void> addMovie({
    required String profileId,
    required String movieId,
  }) async {
    await _dio.put<void>('/profiles/$profileId/favorites/movies/$movieId');
  }

  @override
  Future<void> removeMovie({
    required String profileId,
    required String movieId,
  }) async {
    await _dio.delete<void>('/profiles/$profileId/favorites/movies/$movieId');
  }

  @override
  Future<void> addSeries({
    required String profileId,
    required String seriesId,
  }) async {
    await _dio.put<void>('/profiles/$profileId/favorites/series/$seriesId');
  }

  @override
  Future<void> removeSeries({
    required String profileId,
    required String seriesId,
  }) async {
    await _dio.delete<void>('/profiles/$profileId/favorites/series/$seriesId');
  }
}
