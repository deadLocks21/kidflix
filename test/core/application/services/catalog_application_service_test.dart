import 'package:flutter_test/flutter_test.dart';
import 'package:kidflix/core/application/dtos/continue_watching_card.dto.dart';
import 'package:kidflix/core/application/dtos/continue_watching_item.dto.dart';
import 'package:kidflix/core/application/dtos/movie.dto.dart';
import 'package:kidflix/core/application/dtos/profile.dto.dart';
import 'package:kidflix/core/application/dtos/series.dto.dart';
import 'package:kidflix/core/application/services/catalog_application.service.dart';
import 'package:kidflix/core/application/usecases/resolve_continue_watching.usecase.dart';
import 'package:kidflix/core/domain/model/download_entry.dart';
import 'package:kidflix/core/domain/model/download_kind.dart';
import 'package:kidflix/core/domain/model/media.dart';
import 'package:kidflix/core/domain/model/profile.dart';
import 'package:kidflix/core/domain/model/watch_progress.dart';
import 'package:kidflix/core/domain/services/catalog.repository.dart';
import 'package:kidflix/core/domain/services/series.repository.dart';
import 'package:kidflix/core/domain/services/watch_progress.repository.dart';

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

class _NoopProgressRepo implements WatchProgressRepository {
  @override
  Future<MovieProgress?> findForMovie({
    required String profileId,
    required String movieId,
  }) async => null;
  @override
  Future<EpisodeProgress?> findForEpisode({
    required String profileId,
    required String episodeId,
  }) async => null;
  @override
  Future<void> save(WatchProgress progress) async {}
  @override
  Future<List<WatchProgress>> listForProfile(String profileId) async => const [];
}

class _NoopSeriesRepo implements SeriesRepository {
  @override
  Future<Series> findById(String seriesId) async =>
      throw StateError('not used');
  @override
  Future<Series> findByIdForProfile(String seriesId, String profileId) =>
      findById(seriesId);
}

/// Bypasses the resolve pipeline entirely — returns canned items so the
/// service test can assert how it projects them without rebuilding the
/// catalog/progress/series fakes the usecase consumes upstream.
class _CannedCWUseCase extends ResolveContinueWatchingUseCase {
  final List<ContinueWatchingItemDto> _items;

  _CannedCWUseCase(this._items)
      : super(
          progressRepo: _NoopProgressRepo(),
          catalogRepo: _FakeRepo(const []),
          seriesRepo: _NoopSeriesRepo(),
        );

  @override
  Future<List<ContinueWatchingItemDto>> execute(String profileId) async =>
      List.unmodifiable(_items);
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

    group('Continuer à regarder row', () {
      Movie nemo({Duration duration = const Duration(minutes: 60)}) => Movie(
        id: 'nemo',
        title: 'Nemo',
        duration: duration,
        synopsis: '',
        ageCategory: AgeCategory.enfant,
        genres: const [],
        director: const [],
        cast: const [],
        addedAt: DateTime(2026, 1, 1),
      );

      Series pingu() => Series(
        id: 'pingu',
        title: 'Pingu',
        synopsis: '',
        ageCategory: AgeCategory.enfant,
        genres: const [],
        director: const [],
        cast: const [],
        addedAt: DateTime(2026, 1, 1),
        seasonsCount: 1,
        episodesCount: 1,
      );

      Episode episode({Duration duration = const Duration(minutes: 5)}) =>
          Episode(
            id: 'pingu-s01e01',
            seriesId: 'pingu',
            seasonNumber: 1,
            episodeNumber: 1,
            title: 'Hello',
            duration: duration,
            ageCategory: AgeCategory.enfant,
            addedAt: DateTime(2026, 1, 1),
          );

      test('items are wrapped in ContinueWatchingCardDto', () async {
        final m = nemo();
        final cw = _CannedCWUseCase([
          MovieContinueDto(
            movie: MovieDto.fromDomain(m),
            resumeSeconds: 600,
            completed: false,
          ),
        ]);
        final service = CatalogApplicationService(
          _FakeRepo([m]),
          continueWatching: cw,
        );
        final rows = await service.buildHomeRowsFor(
          _profile(AgeCategory.enfant),
        );
        final row = rows.firstWhere((r) => r.type == 'continueWatching');
        expect(row.items, hasLength(1));
        expect(row.items.first, isA<ContinueWatchingCardDto>());
      });

      test('movie progress = resumeSeconds / duration', () async {
        final m = nemo(duration: const Duration(seconds: 1800));
        final cw = _CannedCWUseCase([
          MovieContinueDto(
            movie: MovieDto.fromDomain(m),
            resumeSeconds: 600,
            completed: false,
          ),
        ]);
        final service = CatalogApplicationService(
          _FakeRepo([m]),
          continueWatching: cw,
        );
        final rows = await service.buildHomeRowsFor(
          _profile(AgeCategory.enfant),
        );
        final row = rows.firstWhere((r) => r.type == 'continueWatching');
        final wrapper = row.items.first as ContinueWatchingCardDto;
        expect(wrapper.progress, closeTo(600 / 1800, 1e-9));
        expect(wrapper.inner, isA<MovieDto>());
      });

      test('movie resume past end clamps to 1.0', () async {
        final m = nemo(duration: const Duration(seconds: 100));
        final cw = _CannedCWUseCase([
          MovieContinueDto(
            movie: MovieDto.fromDomain(m),
            resumeSeconds: 99999,
            completed: false,
          ),
        ]);
        final service = CatalogApplicationService(
          _FakeRepo([m]),
          continueWatching: cw,
        );
        final rows = await service.buildHomeRowsFor(
          _profile(AgeCategory.enfant),
        );
        final row = rows.firstWhere((r) => r.type == 'continueWatching');
        final wrapper = row.items.first as ContinueWatchingCardDto;
        expect(wrapper.progress, 1.0);
      });

      test('movie zero duration → progress 0.0 (no division by zero)',
          () async {
        final m = nemo(duration: Duration.zero);
        final cw = _CannedCWUseCase([
          MovieContinueDto(
            movie: MovieDto.fromDomain(m),
            resumeSeconds: 42,
            completed: false,
          ),
        ]);
        final service = CatalogApplicationService(
          _FakeRepo([m]),
          continueWatching: cw,
        );
        final rows = await service.buildHomeRowsFor(
          _profile(AgeCategory.enfant),
        );
        final row = rows.firstWhere((r) => r.type == 'continueWatching');
        final wrapper = row.items.first as ContinueWatchingCardDto;
        expect(wrapper.progress, 0.0);
      });

      test('episode inProgress → progress = resume / episode duration',
          () async {
        final s = pingu();
        final e = episode(duration: const Duration(seconds: 300));
        final cw = _CannedCWUseCase([
          EpisodeContinueDto(
            series: s,
            episode: e,
            resumeSeconds: 75,
            kind: ContinueWatchingState.inProgress,
          ),
        ]);
        final service = CatalogApplicationService(
          _FakeRepo([s]),
          continueWatching: cw,
        );
        final rows = await service.buildHomeRowsFor(
          _profile(AgeCategory.enfant),
        );
        final row = rows.firstWhere((r) => r.type == 'continueWatching');
        final wrapper = row.items.first as ContinueWatchingCardDto;
        expect(wrapper.progress, closeTo(75 / 300, 1e-9));
        expect(wrapper.inner, isA<SeriesDto>());
      });

      test('episode nextAfterCompleted → progress 0.0', () async {
        final s = pingu();
        final cw = _CannedCWUseCase([
          EpisodeContinueDto(
            series: s,
            episode: episode(),
            resumeSeconds: 0,
            kind: ContinueWatchingState.nextAfterCompleted,
          ),
        ]);
        final service = CatalogApplicationService(
          _FakeRepo([s]),
          continueWatching: cw,
        );
        final rows = await service.buildHomeRowsFor(
          _profile(AgeCategory.enfant),
        );
        final row = rows.firstWhere((r) => r.type == 'continueWatching');
        final wrapper = row.items.first as ContinueWatchingCardDto;
        expect(wrapper.progress, 0.0);
      });

      test('episode restart → progress 0.0', () async {
        final s = pingu();
        final cw = _CannedCWUseCase([
          EpisodeContinueDto(
            series: s,
            episode: episode(),
            resumeSeconds: 0,
            kind: ContinueWatchingState.restart,
          ),
        ]);
        final service = CatalogApplicationService(
          _FakeRepo([s]),
          continueWatching: cw,
        );
        final rows = await service.buildHomeRowsFor(
          _profile(AgeCategory.enfant),
        );
        final row = rows.firstWhere((r) => r.type == 'continueWatching');
        final wrapper = row.items.first as ContinueWatchingCardDto;
        expect(wrapper.progress, 0.0);
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
