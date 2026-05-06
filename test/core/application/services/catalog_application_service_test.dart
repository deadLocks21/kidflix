import 'package:flutter_test/flutter_test.dart';
import 'package:kidflix/core/application/dtos/profile.dto.dart';
import 'package:kidflix/core/application/services/catalog_application.service.dart';
import 'package:kidflix/core/domain/model/download_entry.dart';
import 'package:kidflix/core/domain/model/download_kind.dart';
import 'package:kidflix/core/domain/model/media.dart';
import 'package:kidflix/core/domain/model/profile.dart';
import 'package:kidflix/core/domain/services/catalog.repository.dart';

class _FakeRepo implements CatalogRepository {
  final List<CatalogItem> _pool;

  _FakeRepo(List<CatalogItem> pool) : _pool = pool;

  @override
  Future<List<CatalogItem>> listCatalog() async => List.unmodifiable(_pool);

  @override
  Future<List<CatalogItem>> searchCatalog({required String query}) async =>
      const [];

  @override
  Future<List<CatalogItem>> listCatalogForProfile(String profileId) async =>
      const [];
}

Series _s({
  required String id,
  String title = 'Series',
  int seasonsCount = 2,
  int episodesCount = 10,
  int? year,
  DateTime? addedAt,
  AgeCategory ageCategory = AgeCategory.enfant,
  List<String> genres = const [],
}) =>
    Series(
      id: id,
      title: title,
      synopsis: '',
      ageCategory: ageCategory,
      genres: genres,
      director: const [],
      cast: const [],
      addedAt: addedAt ?? DateTime(2026, 1, 1),
      seasonsCount: seasonsCount,
      episodesCount: episodesCount,
      year: year,
    );

Movie _m({
  required String id,
  String title = 'M',
  AgeCategory ageCategory = AgeCategory.enfant,
  List<String> genres = const [],
  String? sagaId,
  String? sagaLabel,
  int? year,
  DateTime? addedAt,
}) {
  return Movie(
    id: id,
    title: title,
    duration: const Duration(minutes: 90),
    synopsis: '',
    ageCategory: ageCategory,
    genres: genres,
    director: const [],
    cast: const [],
    addedAt: addedAt ?? DateTime(2026, 1, 1),
    year: year,
    sagaId: sagaId,
    sagaLabel: sagaLabel,
  );
}

DownloadEntry _movieDownload({
  required String mediaId,
  required String? triggeredBy,
}) =>
    DownloadEntry(
      mediaId: mediaId,
      mediaKind: DownloadMediaKind.movie,
      kind: DownloadKind.download,
      bytesOnDisk: 100,
      displayTitle: mediaId,
      triggeredByProfileId: triggeredBy,
    );

DownloadEntry _episodeDownload({
  required String mediaId,
  required String parentSeriesId,
  required String? triggeredBy,
}) =>
    DownloadEntry(
      mediaId: mediaId,
      mediaKind: DownloadMediaKind.episode,
      kind: DownloadKind.download,
      bytesOnDisk: 100,
      displayTitle: mediaId,
      triggeredByProfileId: triggeredBy,
      parentSeriesId: parentSeriesId,
    );

ProfileDto _profile(AgeCategory category) => ProfileDto(
  id: 'p1',
  name: 'Kid',
  ageCategory: category.name,
  hasPin: false,
  isMain: false,
);

void main() {
  group('CatalogApplicationService.buildHomeRowsFor', () {
    test(
      'consumes the repository result without re-filtering by age category',
      () async {
        final service = CatalogApplicationService(
          _FakeRepo([
            _m(id: 'b1', ageCategory: AgeCategory.bebe, genres: ['Animation']),
            _m(id: 'e1', ageCategory: AgeCategory.enfant, genres: ['Aventure']),
          ]),
        );
        final rows = await service.buildHomeRowsFor(
          _profile(AgeCategory.enfant),
        );
        final allMovieIds =
            rows.expand((r) => r.items.map((m) => m.id)).toSet();
        // Both movies appear: the service forwards the repository's output
        // verbatim. Filtering is server-side (HTTP) or absent (in-memory).
        expect(allMovieIds, containsAll(['b1', 'e1']));
      },
    );

    test('saga row needs at least 4 movies with same sagaId', () async {
      final service = CatalogApplicationService(
        _FakeRepo([
          for (var i = 0; i < 4; i++)
            _m(
              id: 'a$i',
              sagaId: 'asterix',
              sagaLabel: 'Astérix',
              genres: const ['Familial'],
            ),
          // Below threshold, must be filtered out
          _m(
            id: 's1',
            sagaId: 'harry-potter',
            sagaLabel: 'Harry Potter',
            genres: const ['Fantastique'],
          ),
          _m(
            id: 's2',
            sagaId: 'harry-potter',
            sagaLabel: 'Harry Potter',
            genres: const ['Fantastique'],
          ),
        ]),
      );
      final rows = await service.buildHomeRowsFor(_profile(AgeCategory.enfant));
      final sagaRows = rows.where((r) => r.type == 'saga').toList();
      expect(sagaRows.length, 1);
      expect(sagaRows.single.label, 'Astérix');
      expect(
        sagaRows.single.items.map((m) => m.id).toSet(),
        {'a0', 'a1', 'a2', 'a3'},
      );
    });

    test('film appears only in its primary (first) genre row', () async {
      final service = CatalogApplicationService(
        _FakeRepo([
          for (var i = 0; i < 4; i++)
            _m(id: 'x$i', genres: const ['Familial', 'Comédie', 'Aventure']),
        ]),
      );
      final rows = await service.buildHomeRowsFor(_profile(AgeCategory.enfant));
      final genreRows = rows.where((r) => r.type == 'genre').toList();
      expect(genreRows.length, 1);
      expect(genreRows.single.label, 'Familial');
    });

    test(
      'fixed rows precede dynamic block; dynamic rows come last',
      () async {
        final service = CatalogApplicationService(
          _FakeRepo([
            for (var i = 0; i < 4; i++)
              _m(
                id: 'a$i',
                sagaId: 'asterix',
                sagaLabel: 'Astérix',
                genres: const ['Familial'],
              ),
            for (var i = 0; i < 4; i++)
              _m(id: 'c$i', genres: const ['Comédie']),
          ]),
        );
        final rows = await service.buildHomeRowsFor(
          _profile(AgeCategory.enfant),
        );
        final types = rows.map((r) => r.type).toList();
        final raIdx = types.indexOf('recentlyAdded');
        final favIdx = types.indexOf('favorites');
        final sagaIdx = types.indexOf('saga');
        final genreIdx = types.indexOf('genre');
        expect(raIdx, lessThan(favIdx));
        expect(favIdx, lessThan(sagaIdx));
        expect(favIdx, lessThan(genreIdx));
      },
    );

    test('dynamic rows below the 4-item threshold are hidden', () async {
      final service = CatalogApplicationService(
        _FakeRepo([
          // 3-movie saga: must NOT appear
          for (var i = 0; i < 3; i++)
            _m(
              id: 'p$i',
              sagaId: 'pixar',
              sagaLabel: 'Pixar',
              genres: const ['Animation'],
            ),
          // 4-movie genre: must appear
          for (var i = 0; i < 4; i++)
            _m(id: 'c$i', genres: const ['Comédie']),
        ]),
      );
      final rows = await service.buildHomeRowsFor(_profile(AgeCategory.enfant));
      expect(rows.where((r) => r.type == 'saga'), isEmpty);
      expect(rows.where((r) => r.type == 'genre'), hasLength(1));
    });

    test('recentlyAdded capped at 20 and sorted desc', () async {
      final base = DateTime(2026, 1, 1);
      final movies = [
        for (int i = 0; i < 25; i++)
          _m(
            id: 'm$i',
            genres: const ['Familial'],
            addedAt: base.add(Duration(days: i)),
          ),
      ];
      final service = CatalogApplicationService(_FakeRepo(movies));
      final rows = await service.buildHomeRowsFor(_profile(AgeCategory.enfant));
      final ra = rows.firstWhere((r) => r.type == 'recentlyAdded');
      expect(ra.items.length, 20);
      expect(ra.items.first.id, 'm24');
      expect(ra.items.last.id, 'm5');
    });

    test('empty rows are filtered out', () async {
      final service = CatalogApplicationService(_FakeRepo(const []));
      final rows = await service.buildHomeRowsFor(_profile(AgeCategory.enfant));
      expect(rows, isEmpty);
    });

    test('Recently added mixes movies and series', () async {
      final service = CatalogApplicationService(
        _FakeRepo([
          _m(id: 'm1', addedAt: DateTime(2026, 5, 4)),
          _s(id: 's1', addedAt: DateTime(2026, 5, 3)),
        ]),
      );
      final rows = await service.buildHomeRowsFor(_profile(AgeCategory.enfant));
      final ra = rows.firstWhere((r) => r.type == 'recentlyAdded');
      expect(ra.items.map((i) => i.id), ['m1', 's1']);
    });

    test('Genre row excludes series even when they share the genre', () async {
      final service = CatalogApplicationService(
        _FakeRepo([
          for (var i = 0; i < 4; i++)
            _m(id: 'm$i', genres: const ['Animation']),
          _s(id: 's1', genres: const ['Animation']),
        ]),
      );
      final rows = await service.buildHomeRowsFor(_profile(AgeCategory.enfant));
      final genreRows = rows.where((r) => r.type == 'genre').toList();
      expect(genreRows, hasLength(1));
      expect(genreRows.single.label, 'Animation');
      expect(
        genreRows.single.items.map((i) => i.id).toSet(),
        {'m0', 'm1', 'm2', 'm3'},
      );
    });

    group('Téléchargés row', () {
      test('is absent when no downloads provided', () async {
        final service = CatalogApplicationService(
          _FakeRepo([_m(id: 'm1')]),
        );
        final rows = await service.buildHomeRowsFor(
          _profile(AgeCategory.enfant),
        );
        expect(rows.where((r) => r.type == 'downloaded'), isEmpty);
      });

      test(
        'shows entries triggered by active profile + entries with no '
        'known triggerer; skips items triggered by other profiles',
        () async {
          final service = CatalogApplicationService(
            _FakeRepo([_m(id: 'm1'), _m(id: 'm2'), _m(id: 'm3')]),
          );
          final downloads = [
            _movieDownload(mediaId: 'm1', triggeredBy: 'p1'),
            _movieDownload(mediaId: 'm2', triggeredBy: 'p2'),
            _movieDownload(mediaId: 'm3', triggeredBy: null),
          ];
          final rows = await service.buildHomeRowsFor(
            _profile(AgeCategory.enfant),
            downloads: downloads,
          );
          final dl = rows.firstWhere((r) => r.type == 'downloaded');
          expect(dl.items.map((i) => i.id).toList(), ['m1', 'm3']);
        },
      );

      test('deduplicates episodes of the same series into one series card',
          () async {
        final service = CatalogApplicationService(
          _FakeRepo([_s(id: 'pingu')]),
        );
        final downloads = [
          _episodeDownload(
            mediaId: 'pingu-s01e01',
            parentSeriesId: 'pingu',
            triggeredBy: 'p1',
          ),
          _episodeDownload(
            mediaId: 'pingu-s01e02',
            parentSeriesId: 'pingu',
            triggeredBy: 'p1',
          ),
        ];
        final rows = await service.buildHomeRowsFor(
          _profile(AgeCategory.enfant),
          downloads: downloads,
        );
        final dl = rows.firstWhere((r) => r.type == 'downloaded');
        expect(dl.items.map((i) => i.id).toList(), ['pingu']);
      });

      test('skips entries whose catalog metadata is missing', () async {
        final service = CatalogApplicationService(
          _FakeRepo([_m(id: 'm1')]),
        );
        final downloads = [
          _movieDownload(mediaId: 'm1', triggeredBy: 'p1'),
          _movieDownload(mediaId: 'orphan', triggeredBy: 'p1'),
          _episodeDownload(
            mediaId: 'ghost-ep',
            parentSeriesId: 'ghost-series',
            triggeredBy: 'p1',
          ),
        ];
        final rows = await service.buildHomeRowsFor(
          _profile(AgeCategory.enfant),
          downloads: downloads,
        );
        final dl = rows.firstWhere((r) => r.type == 'downloaded');
        expect(dl.items.map((i) => i.id).toList(), ['m1']);
      });

      test('preserves order of the downloads list (lastPlayedAt-desc)',
          () async {
        final service = CatalogApplicationService(
          _FakeRepo([_m(id: 'm1'), _m(id: 'm2'), _m(id: 'm3')]),
        );
        final downloads = [
          _movieDownload(mediaId: 'm3', triggeredBy: 'p1'),
          _movieDownload(mediaId: 'm1', triggeredBy: 'p1'),
          _movieDownload(mediaId: 'm2', triggeredBy: 'p1'),
        ];
        final rows = await service.buildHomeRowsFor(
          _profile(AgeCategory.enfant),
          downloads: downloads,
        );
        final dl = rows.firstWhere((r) => r.type == 'downloaded');
        expect(dl.items.map((i) => i.id).toList(), ['m3', 'm1', 'm2']);
      });
    });

    test('Saga row excludes series even when they share a sagaId', () async {
      final service = CatalogApplicationService(
        _FakeRepo([
          for (var i = 0; i < 4; i++)
            _m(id: 'm$i', sagaId: 'world', sagaLabel: 'World'),
          _s(id: 's1'), // Series with no saga
        ]),
      );
      final rows = await service.buildHomeRowsFor(_profile(AgeCategory.enfant));
      final saga = rows.firstWhere((r) => r.type == 'saga');
      expect(
        saga.items.map((i) => i.id).toSet(),
        {'m0', 'm1', 'm2', 'm3'},
      );
      expect(saga.items.any((i) => i.id == 's1'), isFalse);
    });
  });
}
