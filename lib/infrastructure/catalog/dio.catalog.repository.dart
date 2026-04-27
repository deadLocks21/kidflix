import 'package:dio/dio.dart';
import 'package:kidflix/core/application/dtos/age_category_wire.dart';
import 'package:kidflix/core/application/dtos/remote_movie.dto.dart';
import 'package:kidflix/core/domain/model/movie.dart';
import 'package:kidflix/core/domain/model/profile.dart';
import 'package:kidflix/core/domain/services/catalog.repository.dart';

/// HTTP implementation of [CatalogRepository] backed by Dio.
///
/// Hits `GET /movies` and `GET /movies/search` per `API.md` § Catalogue. The
/// required `Authorization: Bearer <jwt>` and `X-Device-Id: <uuid>` headers
/// are injected transparently by the `AuthInterceptor` registered on
/// `dioProvider` — this repository never touches headers explicitly.
///
/// No domain-specific exception is mapped: the catalog list endpoints have
/// no documented business error code (no 404 by id, no 422 metier). Any
/// failure (network error, 4xx, 5xx, malformed payload) is rethrown as the
/// original [DioException] for the application layer to surface as a
/// generic error. No retry policy is applied.
class DioCatalogRepository implements CatalogRepository {
  final Dio _dio;

  DioCatalogRepository(this._dio);

  @override
  Future<List<Movie>> listMoviesFor(AgeCategory ageCategory) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/movies',
      queryParameters: {'age_category': ageCategoryToWire(ageCategory)},
    );
    return _parseMovies(response.data!);
  }

  @override
  Future<List<Movie>> searchMovies({
    required String query,
    required AgeCategory upToAgeCategory,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/movies/search',
      queryParameters: {
        'q': query,
        'up_to_age_category': ageCategoryToWire(upToAgeCategory),
      },
    );
    return _parseMovies(response.data!);
  }

  List<Movie> _parseMovies(Map<String, dynamic> body) {
    final raw = (body['movies'] as List).cast<Map<String, dynamic>>();
    return raw
        .map(RemoteMovieDto.fromJson)
        .map((d) => d.toDomain())
        .toList(growable: false);
  }
}
