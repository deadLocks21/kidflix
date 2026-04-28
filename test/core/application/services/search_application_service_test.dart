import 'package:flutter_test/flutter_test.dart';
import 'package:kidflix/core/application/dtos/profile.dto.dart';
import 'package:kidflix/core/application/services/search_application.service.dart';
import 'package:kidflix/core/domain/model/movie.dart';
import 'package:kidflix/core/domain/model/profile.dart';
import 'package:kidflix/core/domain/services/catalog.repository.dart';

class _RecordingRepo implements CatalogRepository {
  final List<Movie> results;

  String? lastQuery;
  int callCount = 0;

  _RecordingRepo(this.results);

  @override
  Future<List<Movie>> listMoviesFor() async => throw UnimplementedError();

  @override
  Future<List<Movie>> searchMovies({required String query}) async {
    lastQuery = query;
    callCount += 1;
    return results;
  }
}

Movie _m(String id, String title, {AgeCategory age = AgeCategory.enfant}) {
  return Movie(
    id: id,
    title: title,
    duration: const Duration(minutes: 90),
    synopsis: '',
    ageCategory: age,
    genres: const [],
    director: const [],
    cast: const [],
    addedAt: DateTime(2026, 1, 1),
  );
}

const _profile = ProfileDto(
  id: 'p1',
  name: 'Kid',
  ageCategory: 'ado',
  hasPin: false,
  isMain: false,
);

void main() {
  group('SearchApplicationService.searchFor', () {
    test('forwards the query to the repository (no age parameter)', () async {
      final repo = _RecordingRepo([_m('x', 'X')]);
      final service = SearchApplicationService(repo);
      await service.searchFor(query: 'whatever', profile: _profile);
      expect(repo.lastQuery, 'whatever');
      expect(repo.callCount, 1);
    });

    test('sorts results alphabetically by title', () async {
      final repo = _RecordingRepo([
        _m('c', 'Totoro'),
        _m('a', 'Astérix'),
        _m('b', 'Harry Potter'),
      ]);
      final service = SearchApplicationService(repo);
      final result = await service.searchFor(query: 'q', profile: _profile);
      expect(
        result.map((m) => m.title).toList(),
        ['Astérix', 'Harry Potter', 'Totoro'],
      );
    });

    test('returns MovieDto (no Movie entities cross the boundary)', () async {
      final repo = _RecordingRepo([_m('x', 'X')]);
      final service = SearchApplicationService(repo);
      final result = await service.searchFor(query: 'q', profile: _profile);
      expect(result, isNotEmpty);
      expect(result.first.id, 'x');
    });

    test('empty repository result yields empty dto list', () async {
      final repo = _RecordingRepo([]);
      final service = SearchApplicationService(repo);
      final result = await service.searchFor(query: 'q', profile: _profile);
      expect(result, isEmpty);
    });
  });
}
