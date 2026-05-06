import 'package:flutter_test/flutter_test.dart';
import 'package:kidflix/core/application/dtos/continue_watching_item.dto.dart';
import 'package:kidflix/core/application/usecases/resolve_continue_watching.usecase.dart';
import 'package:kidflix/core/domain/model/media.dart';
import 'package:kidflix/core/domain/model/profile.dart';
import 'package:kidflix/core/domain/model/watch_progress.dart';
import 'package:kidflix/core/domain/services/catalog.repository.dart';
import 'package:kidflix/core/domain/services/series.repository.dart';
import 'package:kidflix/core/domain/services/watch_progress.repository.dart';

Movie _movie({String id = 'nemo', String title = 'Nemo'}) => Movie(
      id: id,
      title: title,
      duration: const Duration(minutes: 100),
      synopsis: '',
      ageCategory: AgeCategory.enfant,
      genres: const [],
      director: const [],
      cast: const [],
      addedAt: DateTime(2026, 4, 1),
    );

Episode _ep({
  required String id,
  String seriesId = 'pingu',
  required int seasonNumber,
  required int episodeNumber,
}) =>
    Episode(
      id: id,
      seriesId: seriesId,
      seasonNumber: seasonNumber,
      episodeNumber: episodeNumber,
      title: 'Ep $seasonNumber.$episodeNumber',
      duration: const Duration(minutes: 5),
      ageCategory: AgeCategory.enfant,
      addedAt: DateTime(2026, 5, 1),
    );

Series _seriesWith({
  required String id,
  required List<Season> seasons,
}) {
  final epCount = seasons.fold<int>(0, (s, sn) => s + sn.episodes.length);
  return Series(
    id: id,
    title: id.toUpperCase(),
    synopsis: '',
    ageCategory: AgeCategory.enfant,
    genres: const [],
    director: const [],
    cast: const [],
    addedAt: DateTime(2026, 5, 1),
    seasonsCount: seasons.length,
    episodesCount: epCount,
    seasons: seasons,
  );
}

class _FakeCatalog implements CatalogRepository {
  _FakeCatalog(this._items);
  final List<CatalogItem> _items;
  @override
  Future<List<CatalogItem>> listCatalog() async => _items;
  @override
  Future<List<CatalogItem>> searchCatalog({required String query}) async => [];
  @override
  Future<List<CatalogItem>> listCatalogForProfile(String profileId) =>
      listCatalog();
}

class _FakeSeries implements SeriesRepository {
  _FakeSeries(this._byId);
  final Map<String, Series> _byId;
  Object? throwForId;
  @override
  Future<Series> findById(String seriesId) async {
    if (throwForId == seriesId) throw StateError('series-down');
    final hit = _byId[seriesId];
    if (hit == null) throw StateError('not found: $seriesId');
    return hit;
  }

  @override
  Future<Series> findByIdForProfile(String seriesId, String profileId) =>
      findById(seriesId);
}

class _FakeProgress implements WatchProgressRepository {
  _FakeProgress(this._entries);
  final List<WatchProgress> _entries;
  @override
  Future<List<WatchProgress>> listForProfile(String profileId) async =>
      _entries.where((e) => e.profileId == profileId).toList();
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
}

void main() {
  group('ResolveContinueWatchingUseCase', () {
    test('empty when profile has no progress', () async {
      final uc = ResolveContinueWatchingUseCase(
        progressRepo: _FakeProgress([]),
        catalogRepo: _FakeCatalog([]),
        seriesRepo: _FakeSeries({}),
      );
      expect(await uc.execute('p1'), isEmpty);
    });

    test('single in-progress movie produces a MovieContinueDto', () async {
      final movie = _movie();
      final progress = MovieProgress(
        profileId: 'p1',
        movieId: 'nemo',
        positionSeconds: 1845,
        completed: false,
        updatedAt: DateTime(2026, 5, 4),
      );
      final uc = ResolveContinueWatchingUseCase(
        progressRepo: _FakeProgress([progress]),
        catalogRepo: _FakeCatalog([movie]),
        seriesRepo: _FakeSeries({}),
      );

      final result = await uc.execute('p1');

      expect(result, hasLength(1));
      expect(result.single, isA<MovieContinueDto>());
      final m = result.single as MovieContinueDto;
      expect(m.movie.id, 'nemo');
      expect(m.resumeSeconds, 1845);
      expect(m.completed, isFalse);
    });

    test('in-progress episode produces an inProgress EpisodeContinueDto',
        () async {
      final s1e3 = _ep(id: 's1e3', seasonNumber: 1, episodeNumber: 3);
      final series = _seriesWith(
        id: 'pingu',
        seasons: [
          Season(seasonNumber: 1, episodes: [
            _ep(id: 's1e1', seasonNumber: 1, episodeNumber: 1),
            _ep(id: 's1e2', seasonNumber: 1, episodeNumber: 2),
            s1e3,
            _ep(id: 's1e4', seasonNumber: 1, episodeNumber: 4),
          ]),
        ],
      );
      final progress = EpisodeProgress(
        profileId: 'p1',
        episodeId: 's1e3',
        positionSeconds: 240,
        completed: false,
        updatedAt: DateTime(2026, 5, 4),
      );
      final uc = ResolveContinueWatchingUseCase(
        progressRepo: _FakeProgress([progress]),
        // Catalog projection: series id only (no seasons).
        catalogRepo:
            _FakeCatalog([_seriesWith(id: 'pingu', seasons: const [])]),
        seriesRepo: _FakeSeries({'pingu': series}),
      );

      final result = await uc.execute('p1');

      expect(result, hasLength(1));
      final e = result.single as EpisodeContinueDto;
      expect(e.episode.id, 's1e3');
      expect(e.resumeSeconds, 240);
      expect(e.kind, ContinueWatchingState.inProgress);
    });

    test('completed episode mid-season → next episode same season', () async {
      final series = _seriesWith(
        id: 'pingu',
        seasons: [
          Season(seasonNumber: 1, episodes: [
            _ep(id: 's1e1', seasonNumber: 1, episodeNumber: 1),
            _ep(id: 's1e2', seasonNumber: 1, episodeNumber: 2),
            _ep(id: 's1e3', seasonNumber: 1, episodeNumber: 3),
            _ep(id: 's1e4', seasonNumber: 1, episodeNumber: 4),
          ]),
        ],
      );
      final progress = EpisodeProgress(
        profileId: 'p1',
        episodeId: 's1e3',
        positionSeconds: 290,
        completed: true,
        updatedAt: DateTime(2026, 5, 4),
      );
      final uc = ResolveContinueWatchingUseCase(
        progressRepo: _FakeProgress([progress]),
        catalogRepo:
            _FakeCatalog([_seriesWith(id: 'pingu', seasons: const [])]),
        seriesRepo: _FakeSeries({'pingu': series}),
      );

      final result = await uc.execute('p1');

      final e = result.single as EpisodeContinueDto;
      expect(e.episode.id, 's1e4');
      expect(e.kind, ContinueWatchingState.nextAfterCompleted);
      expect(e.resumeSeconds, 0);
    });

    test('completed last episode of season → first episode of next season',
        () async {
      final series = _seriesWith(
        id: 'pingu',
        seasons: [
          Season(seasonNumber: 1, episodes: [
            _ep(id: 's1e1', seasonNumber: 1, episodeNumber: 1),
            _ep(id: 's1e2', seasonNumber: 1, episodeNumber: 2),
          ]),
          Season(seasonNumber: 2, episodes: [
            _ep(id: 's2e1', seasonNumber: 2, episodeNumber: 1),
          ]),
        ],
      );
      final progress = EpisodeProgress(
        profileId: 'p1',
        episodeId: 's1e2',
        positionSeconds: 290,
        completed: true,
        updatedAt: DateTime(2026, 5, 4),
      );
      final uc = ResolveContinueWatchingUseCase(
        progressRepo: _FakeProgress([progress]),
        catalogRepo:
            _FakeCatalog([_seriesWith(id: 'pingu', seasons: const [])]),
        seriesRepo: _FakeSeries({'pingu': series}),
      );

      final e = (await uc.execute('p1')).single as EpisodeContinueDto;
      expect(e.episode.id, 's2e1');
      expect(e.kind, ContinueWatchingState.nextAfterCompleted);
    });

    test('completed end of series → restart at S1E1', () async {
      final series = _seriesWith(
        id: 'pingu',
        seasons: [
          Season(seasonNumber: 1, episodes: [
            _ep(id: 's1e1', seasonNumber: 1, episodeNumber: 1),
            _ep(id: 's1e2', seasonNumber: 1, episodeNumber: 2),
          ]),
        ],
      );
      final progress = EpisodeProgress(
        profileId: 'p1',
        episodeId: 's1e2',
        positionSeconds: 290,
        completed: true,
        updatedAt: DateTime(2026, 5, 4),
      );
      final uc = ResolveContinueWatchingUseCase(
        progressRepo: _FakeProgress([progress]),
        catalogRepo:
            _FakeCatalog([_seriesWith(id: 'pingu', seasons: const [])]),
        seriesRepo: _FakeSeries({'pingu': series}),
      );

      final e = (await uc.execute('p1')).single as EpisodeContinueDto;
      expect(e.episode.id, 's1e1');
      expect(e.kind, ContinueWatchingState.restart);
    });

    test('Specials are skipped from rotation when at end of series', () async {
      // Last regular episode completed, plus a Specials season that
      // should NOT be picked as "next".
      final series = _seriesWith(
        id: 'pingu',
        seasons: [
          Season(seasonNumber: 0, name: 'Specials', episodes: [
            _ep(id: 'sp1', seasonNumber: 0, episodeNumber: 1),
          ]),
          Season(seasonNumber: 1, episodes: [
            _ep(id: 's1e1', seasonNumber: 1, episodeNumber: 1),
          ]),
        ],
      );
      final progress = EpisodeProgress(
        profileId: 'p1',
        episodeId: 's1e1',
        positionSeconds: 290,
        completed: true,
        updatedAt: DateTime(2026, 5, 4),
      );
      final uc = ResolveContinueWatchingUseCase(
        progressRepo: _FakeProgress([progress]),
        catalogRepo:
            _FakeCatalog([_seriesWith(id: 'pingu', seasons: const [])]),
        seriesRepo: _FakeSeries({'pingu': series}),
      );

      final e = (await uc.execute('p1')).single as EpisodeContinueDto;
      // Restarted at S1E1, NOT a Specials episode.
      expect(e.episode.seasonNumber, 1);
      expect(e.episode.id, 's1e1');
      expect(e.kind, ContinueWatchingState.restart);
    });

    test(
        'two progressions on the same series → most recent wins after dedup',
        () async {
      final series = _seriesWith(
        id: 'pingu',
        seasons: [
          Season(seasonNumber: 1, episodes: [
            _ep(id: 's1e2', seasonNumber: 1, episodeNumber: 2),
            _ep(id: 's1e3', seasonNumber: 1, episodeNumber: 3),
          ]),
        ],
      );
      final older = EpisodeProgress(
        profileId: 'p1',
        episodeId: 's1e2',
        positionSeconds: 290,
        completed: true,
        updatedAt: DateTime(2026, 5, 1),
      );
      final newer = EpisodeProgress(
        profileId: 'p1',
        episodeId: 's1e3',
        positionSeconds: 100,
        completed: false,
        updatedAt: DateTime(2026, 5, 4),
      );
      final uc = ResolveContinueWatchingUseCase(
        progressRepo: _FakeProgress([older, newer]),
        catalogRepo:
            _FakeCatalog([_seriesWith(id: 'pingu', seasons: const [])]),
        seriesRepo: _FakeSeries({'pingu': series}),
      );

      final result = await uc.execute('p1');

      expect(result, hasLength(1));
      final e = result.single as EpisodeContinueDto;
      // The newer entry (s1e3 in-progress) wins.
      expect(e.episode.id, 's1e3');
      expect(e.kind, ContinueWatchingState.inProgress);
      expect(e.resumeSeconds, 100);
    });

    test('series.findById throws → entry omitted, others kept', () async {
      final pinguSeries = _seriesWith(
        id: 'pingu',
        seasons: [
          Season(seasonNumber: 1, episodes: [
            _ep(id: 's1e1', seasonNumber: 1, episodeNumber: 1),
          ]),
        ],
      );
      final progressA = EpisodeProgress(
        profileId: 'p1',
        episodeId: 's1e1', // pingu
        positionSeconds: 100,
        completed: false,
        updatedAt: DateTime(2026, 5, 4),
      );
      final progressB = MovieProgress(
        profileId: 'p1',
        movieId: 'nemo',
        positionSeconds: 1000,
        completed: false,
        updatedAt: DateTime(2026, 5, 3),
      );
      final fakeSeries = _FakeSeries({'pingu': pinguSeries});
      fakeSeries.throwForId = 'pingu';

      final uc = ResolveContinueWatchingUseCase(
        progressRepo: _FakeProgress([progressA, progressB]),
        catalogRepo: _FakeCatalog([
          _movie(id: 'nemo'),
          _seriesWith(id: 'pingu', seasons: const []),
        ]),
        seriesRepo: fakeSeries,
      );

      final result = await uc.execute('p1');

      // Pingu entry was omitted (findById threw); Nemo movie remains.
      expect(result, hasLength(1));
      expect(result.single, isA<MovieContinueDto>());
      expect((result.single as MovieContinueDto).movie.id, 'nemo');
    });

    test(
        'mixed movie and episode entries are sorted by updatedAt desc',
        () async {
      final pinguSeries = _seriesWith(
        id: 'pingu',
        seasons: [
          Season(seasonNumber: 1, episodes: [
            _ep(id: 's1e3', seasonNumber: 1, episodeNumber: 3),
          ]),
        ],
      );
      final movieProgress = MovieProgress(
        profileId: 'p1',
        movieId: 'nemo',
        positionSeconds: 1000,
        completed: false,
        updatedAt: DateTime(2026, 5, 3),
      );
      final episodeProgress = EpisodeProgress(
        profileId: 'p1',
        episodeId: 's1e3',
        positionSeconds: 100,
        completed: false,
        updatedAt: DateTime(2026, 5, 4),
      );

      final uc = ResolveContinueWatchingUseCase(
        progressRepo: _FakeProgress([movieProgress, episodeProgress]),
        catalogRepo: _FakeCatalog([
          _movie(id: 'nemo'),
          _seriesWith(id: 'pingu', seasons: const []),
        ]),
        seriesRepo: _FakeSeries({'pingu': pinguSeries}),
      );

      final result = await uc.execute('p1');

      expect(result, hasLength(2));
      // Episode entry is newer → first.
      expect(result[0], isA<EpisodeContinueDto>());
      expect(result[1], isA<MovieContinueDto>());
    });
  });
}
