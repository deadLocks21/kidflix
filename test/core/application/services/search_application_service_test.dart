import 'package:flutter_test/flutter_test.dart';
import 'package:kidflix/core/application/dtos/movie.dto.dart';
import 'package:kidflix/core/application/dtos/profile.dto.dart';
import 'package:kidflix/core/application/dtos/series.dto.dart';
import 'package:kidflix/core/application/services/search_application.service.dart';
import 'package:kidflix/core/domain/model/media.dart';
import 'package:kidflix/core/domain/model/profile.dart';
import 'package:kidflix/core/domain/services/catalog.repository.dart';

class _RecordingRepo implements CatalogRepository {
  final List<CatalogItem> results;

  String? lastQuery;
  int callCount = 0;

  _RecordingRepo(this.results);

  @override
  Future<List<CatalogItem>> listCatalog() async => throw UnimplementedError();

  @override
  Future<List<CatalogItem>> searchCatalog({required String query}) async {
    lastQuery = query;
    callCount += 1;
    return results;
  }

  @override
  Future<List<CatalogItem>> listCatalogForProfile(String profileId) async =>
      throw UnimplementedError();
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

Series _s(String id, String title, {AgeCategory age = AgeCategory.ado}) =>
    Series(
      id: id,
      title: title,
      synopsis: '',
      ageCategory: age,
      genres: const [],
      director: const [],
      cast: const [],
      addedAt: DateTime(2026, 5, 1),
      seasonsCount: 5,
      episodesCount: 96,
    );

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
      expect(result.map((i) => i.title).toList(), [
        'Astérix',
        'Harry Potter',
        'Totoro',
      ]);
    });

    test('returns mixed CatalogItemDto (movies + series)', () async {
      final repo = _RecordingRepo([
        _m('m1', 'Astérix'),
        _s('s1', 'Code Lyoko'),
      ]);
      final service = SearchApplicationService(repo);
      final result = await service.searchFor(query: 'q', profile: _profile);
      expect(result, hasLength(2));
      expect(result.whereType<MovieDto>(), hasLength(1));
      expect(result.whereType<SeriesDto>(), hasLength(1));
    });

    test('alphabetical sort applies across both kinds', () async {
      final repo = _RecordingRepo([
        _s('s1', 'Zelda'),
        _m('m1', 'Astérix'),
        _s('s2', 'Pingu'),
      ]);
      final service = SearchApplicationService(repo);
      final result = await service.searchFor(query: 'q', profile: _profile);
      expect(result.map((i) => i.title).toList(), [
        'Astérix',
        'Pingu',
        'Zelda',
      ]);
    });

    test('empty repository result yields empty dto list', () async {
      final repo = _RecordingRepo([]);
      final service = SearchApplicationService(repo);
      final result = await service.searchFor(query: 'q', profile: _profile);
      expect(result, isEmpty);
    });
  });
}
