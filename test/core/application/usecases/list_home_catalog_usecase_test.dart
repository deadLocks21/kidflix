import 'package:flutter_test/flutter_test.dart';
import 'package:kidflix/core/application/dtos/profile.dto.dart';
import 'package:kidflix/core/application/services/catalog_application.service.dart';
import 'package:kidflix/core/application/usecases/list_home_catalog.usecase.dart';
import 'package:kidflix/core/domain/model/movie.dart';
import 'package:kidflix/core/domain/model/profile.dart';
import 'package:kidflix/core/domain/services/catalog.repository.dart';

class _FakeRepo implements CatalogRepository {
  @override
  Future<List<Movie>> listMoviesFor(AgeCategory ageCategory) async {
    return [
      Movie(
        id: 'm1',
        title: 'M1',
        duration: const Duration(minutes: 90),
        synopsis: '',
        ageCategory: ageCategory,
        genres: const ['Animation'],
        director: const [],
        cast: const [],
        addedAt: DateTime(2026, 1, 1),
      ),
    ];
  }

  @override
  Future<List<Movie>> searchMovies({
    required String query,
    required AgeCategory upToAgeCategory,
  }) async => const [];
}

void main() {
  test('ListHomeCatalogUseCase delegates to the service', () async {
    final service = CatalogApplicationService(_FakeRepo());
    final useCase = ListHomeCatalogUseCase(service);
    final rows = await useCase.execute(
      const ProfileDto(
        id: 'p1',
        name: 'Kid',
        ageCategory: 'enfant',
        hasPin: false,
        isMain: false,
      ),
    );
    expect(rows, isNotEmpty);
    final allIds = rows.expand((r) => r.movies.map((m) => m.id)).toSet();
    expect(allIds, contains('m1'));
  });
}
