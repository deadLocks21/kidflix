import 'package:flutter_test/flutter_test.dart';
import 'package:kidflix/core/application/dtos/profile.dto.dart';
import 'package:kidflix/core/application/services/logger_application.service.dart';
import 'package:kidflix/core/application/services/search_application.service.dart';
import 'package:kidflix/core/application/usecases/search_movies.usecase.dart';
import 'package:kidflix/core/domain/model/media.dart';
import 'package:kidflix/core/domain/model/profile.dart';
import 'package:kidflix/core/domain/services/catalog.repository.dart';
import 'package:kidflix/infrastructure/logger/in_memory.logger.service.dart';

class _FakeRepo implements CatalogRepository {
  @override
  Future<List<Movie>> listCatalog() async => const [];

  @override
  Future<List<Movie>> searchCatalog({required String query}) async => [
    Movie(
      id: 'm1',
      title: 'M1',
      duration: const Duration(minutes: 90),
      synopsis: '',
      ageCategory: AgeCategory.enfant,
      genres: const [],
      director: const [],
      cast: const [],
      addedAt: DateTime(2026, 1, 1),
    ),
  ];

  @override
  Future<List<CatalogItem>> listCatalogForProfile(String profileId) async =>
      const [];
}

void main() {
  test('SearchMoviesUseCase delegates to the service', () async {
    final service = SearchApplicationService(_FakeRepo());
    final useCase = SearchMoviesUseCase(
      service,
      LoggerApplicationService(InMemoryLoggerService()),
    );
    final result = await useCase.execute(
      query: 'query',
      profile: const ProfileDto(
        id: 'p1',
        name: 'Kid',
        ageCategory: 'enfant',
        hasPin: false,
        isMain: false,
      ),
    );
    expect(result.map((m) => m.id).toList(), ['m1']);
  });
}
