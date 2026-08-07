import 'package:flutter_test/flutter_test.dart';
import 'package:kidflix/core/application/dtos/continue_watching_item.dto.dart';
import 'package:kidflix/core/application/services/logger_application.service.dart';
import 'package:kidflix/core/application/usecases/resolve_continue_watching.usecase.dart';
import 'package:kidflix/core/domain/model/media.dart';
import 'package:kidflix/core/domain/model/profile.dart';
import 'package:kidflix/core/domain/model/watch_progress.dart';
import 'package:kidflix/core/domain/services/catalog.repository.dart';
import 'package:kidflix/core/domain/services/series.repository.dart';
import 'package:kidflix/core/domain/services/watch_progress.repository.dart';
import 'package:kidflix/infrastructure/logger/in_memory.logger.service.dart';

final _logger = LoggerApplicationService(InMemoryLoggerService());

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
}) => Episode(
  id: id,
  seriesId: seriesId,
  seasonNumber: seasonNumber,
  episodeNumber: episodeNumber,
  title: 'Ep $seasonNumber.$episodeNumber',
  duration: const Duration(minutes: 5),
  ageCategory: AgeCategory.enfant,
  addedAt: DateTime(2026, 5, 1),
);

Series _seriesWith({required String id, required List<Season> seasons}) {
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

  /// Number of `listCatalog()` round-trips — the home used to trigger
  /// three or more per load.
  int listCalls = 0;

  @override
  Future<List<CatalogItem>> listCatalog() async {
    listCalls++;
    return _items;
  }

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

  /// Every `findById` in call order — the assertion surface for the
  /// N×M regression this use case used to carry.
  final List<String> findByIdCalls = [];

  @override
  Future<Series> findById(String seriesId) async {
    findByIdCalls.add(seriesId);
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
  @override
  Future<void> dismissMovie({
    required String profileId,
    required String movieId,
  }) async {}
  @override
  Future<void> unDismissMovie({
    required String profileId,
    required String movieId,
  }) async {}
  @override
  Future<void> dismissEpisode({
    required String profileId,
    required String episodeId,
  }) async {}
  @override
  Future<void> unDismissEpisode({
    required String profileId,
    required String episodeId,
  }) async {}
}

void main() {
  group('ResolveContinueWatchingUseCase', () {
    test('empty when profile has no progress', () async {
      final uc = ResolveContinueWatchingUseCase(
        progressRepo: _FakeProgress([]),
        catalogRepo: _FakeCatalog([]),
        seriesRepo: _FakeSeries({}),
        logger: _logger,
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
        logger: _logger,
      );

      final result = await uc.execute('p1');

      expect(result, hasLength(1));
      expect(result.single, isA<MovieContinueDto>());
      final m = result.single as MovieContinueDto;
      expect(m.movie.id, 'nemo');
      expect(m.resumeSeconds, 1845);
      expect(m.completed, isFalse);
    });

    test('dismissed movie is excluded from Continue Watching', () async {
      final movie = _movie();
      final progress = MovieProgress(
        profileId: 'p1',
        movieId: 'nemo',
        positionSeconds: 600,
        completed: false,
        dismissed: true,
        updatedAt: DateTime(2026, 5, 6),
      );
      final uc = ResolveContinueWatchingUseCase(
        progressRepo: _FakeProgress([progress]),
        catalogRepo: _FakeCatalog([movie]),
        seriesRepo: _FakeSeries({}),
        logger: _logger,
      );

      final result = await uc.execute('p1');

      expect(result, isEmpty);
    });

    test('dismissed episode is excluded from Continue Watching', () async {
      final s1e3 = _ep(id: 's1e3', seasonNumber: 1, episodeNumber: 3);
      final series = _seriesWith(
        id: 'pingu',
        seasons: [
          Season(seasonNumber: 1, episodes: [s1e3]),
        ],
      );
      final progress = EpisodeProgress(
        profileId: 'p1',
        episodeId: 's1e3',
        positionSeconds: 100,
        completed: false,
        dismissed: true,
        updatedAt: DateTime(2026, 5, 6),
      );
      final uc = ResolveContinueWatchingUseCase(
        progressRepo: _FakeProgress([progress]),
        catalogRepo: _FakeCatalog([
          _seriesWith(id: 'pingu', seasons: const []),
        ]),
        seriesRepo: _FakeSeries({'pingu': series}),
        logger: _logger,
      );

      final result = await uc.execute('p1');

      expect(result, isEmpty);
    });

    test('completed movie is excluded from Continue Watching', () async {
      final movie = _movie();
      final progress = MovieProgress(
        profileId: 'p1',
        movieId: 'nemo',
        positionSeconds: 0,
        completed: true,
        updatedAt: DateTime(2026, 5, 6),
      );
      final uc = ResolveContinueWatchingUseCase(
        progressRepo: _FakeProgress([progress]),
        catalogRepo: _FakeCatalog([movie]),
        seriesRepo: _FakeSeries({}),
        logger: _logger,
      );

      final result = await uc.execute('p1');

      expect(result, isEmpty);
    });

    test(
      'in-progress episode produces an inProgress EpisodeContinueDto',
      () async {
        final s1e3 = _ep(id: 's1e3', seasonNumber: 1, episodeNumber: 3);
        final series = _seriesWith(
          id: 'pingu',
          seasons: [
            Season(
              seasonNumber: 1,
              episodes: [
                _ep(id: 's1e1', seasonNumber: 1, episodeNumber: 1),
                _ep(id: 's1e2', seasonNumber: 1, episodeNumber: 2),
                s1e3,
                _ep(id: 's1e4', seasonNumber: 1, episodeNumber: 4),
              ],
            ),
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
          catalogRepo: _FakeCatalog([
            _seriesWith(id: 'pingu', seasons: const []),
          ]),
          seriesRepo: _FakeSeries({'pingu': series}),
          logger: _logger,
        );

        final result = await uc.execute('p1');

        expect(result, hasLength(1));
        final e = result.single as EpisodeContinueDto;
        expect(e.episode.id, 's1e3');
        expect(e.resumeSeconds, 240);
        expect(e.kind, ContinueWatchingState.inProgress);
      },
    );

    test('completed episode mid-season → next episode same season', () async {
      final series = _seriesWith(
        id: 'pingu',
        seasons: [
          Season(
            seasonNumber: 1,
            episodes: [
              _ep(id: 's1e1', seasonNumber: 1, episodeNumber: 1),
              _ep(id: 's1e2', seasonNumber: 1, episodeNumber: 2),
              _ep(id: 's1e3', seasonNumber: 1, episodeNumber: 3),
              _ep(id: 's1e4', seasonNumber: 1, episodeNumber: 4),
            ],
          ),
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
        catalogRepo: _FakeCatalog([
          _seriesWith(id: 'pingu', seasons: const []),
        ]),
        seriesRepo: _FakeSeries({'pingu': series}),
        logger: _logger,
      );

      final result = await uc.execute('p1');

      final e = result.single as EpisodeContinueDto;
      expect(e.episode.id, 's1e4');
      expect(e.kind, ContinueWatchingState.nextAfterCompleted);
      expect(e.resumeSeconds, 0);
    });

    test(
      'completed last episode of season → first episode of next season',
      () async {
        final series = _seriesWith(
          id: 'pingu',
          seasons: [
            Season(
              seasonNumber: 1,
              episodes: [
                _ep(id: 's1e1', seasonNumber: 1, episodeNumber: 1),
                _ep(id: 's1e2', seasonNumber: 1, episodeNumber: 2),
              ],
            ),
            Season(
              seasonNumber: 2,
              episodes: [_ep(id: 's2e1', seasonNumber: 2, episodeNumber: 1)],
            ),
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
          catalogRepo: _FakeCatalog([
            _seriesWith(id: 'pingu', seasons: const []),
          ]),
          seriesRepo: _FakeSeries({'pingu': series}),
          logger: _logger,
        );

        final e = (await uc.execute('p1')).single as EpisodeContinueDto;
        expect(e.episode.id, 's2e1');
        expect(e.kind, ContinueWatchingState.nextAfterCompleted);
      },
    );

    test('completed end of series → restart at S1E1', () async {
      final series = _seriesWith(
        id: 'pingu',
        seasons: [
          Season(
            seasonNumber: 1,
            episodes: [
              _ep(id: 's1e1', seasonNumber: 1, episodeNumber: 1),
              _ep(id: 's1e2', seasonNumber: 1, episodeNumber: 2),
            ],
          ),
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
        catalogRepo: _FakeCatalog([
          _seriesWith(id: 'pingu', seasons: const []),
        ]),
        seriesRepo: _FakeSeries({'pingu': series}),
        logger: _logger,
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
          Season(
            seasonNumber: 0,
            name: 'Specials',
            episodes: [_ep(id: 'sp1', seasonNumber: 0, episodeNumber: 1)],
          ),
          Season(
            seasonNumber: 1,
            episodes: [_ep(id: 's1e1', seasonNumber: 1, episodeNumber: 1)],
          ),
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
        catalogRepo: _FakeCatalog([
          _seriesWith(id: 'pingu', seasons: const []),
        ]),
        seriesRepo: _FakeSeries({'pingu': series}),
        logger: _logger,
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
            Season(
              seasonNumber: 1,
              episodes: [
                _ep(id: 's1e2', seasonNumber: 1, episodeNumber: 2),
                _ep(id: 's1e3', seasonNumber: 1, episodeNumber: 3),
              ],
            ),
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
          catalogRepo: _FakeCatalog([
            _seriesWith(id: 'pingu', seasons: const []),
          ]),
          seriesRepo: _FakeSeries({'pingu': series}),
          logger: _logger,
        );

        final result = await uc.execute('p1');

        expect(result, hasLength(1));
        final e = result.single as EpisodeContinueDto;
        // The newer entry (s1e3 in-progress) wins.
        expect(e.episode.id, 's1e3');
        expect(e.kind, ContinueWatchingState.inProgress);
        expect(e.resumeSeconds, 100);
      },
    );

    test('series.findById throws → entry omitted, others kept', () async {
      final pinguSeries = _seriesWith(
        id: 'pingu',
        seasons: [
          Season(
            seasonNumber: 1,
            episodes: [_ep(id: 's1e1', seasonNumber: 1, episodeNumber: 1)],
          ),
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
        logger: _logger,
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
            Season(
              seasonNumber: 1,
              episodes: [_ep(id: 's1e3', seasonNumber: 1, episodeNumber: 3)],
            ),
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
          logger: _logger,
        );

        final result = await uc.execute('p1');

        expect(result, hasLength(2));
        // Episode entry is newer → first.
        expect(result[0], isA<EpisodeContinueDto>());
        expect(result[1], isA<MovieContinueDto>());
      },
    );

    group('network shape', () {
      /// Builds a catalog of [count] series, each with one episode
      /// `<id>-e1`, plus the matching full-detail map for `_FakeSeries`.
      ({List<CatalogItem> catalog, Map<String, Series> details}) bigCatalog(
        int count,
      ) {
        final catalog = <CatalogItem>[];
        final details = <String, Series>{};
        for (var i = 0; i < count; i++) {
          final id = 'series-$i';
          catalog.add(_seriesWith(id: id, seasons: const []));
          details[id] = _seriesWith(
            id: id,
            seasons: [
              Season(
                seasonNumber: 1,
                episodes: [
                  _ep(
                    id: '$id-e1',
                    seriesId: id,
                    seasonNumber: 1,
                    episodeNumber: 1,
                  ),
                ],
              ),
            ],
          );
        }
        return (catalog: catalog, details: details);
      }

      EpisodeProgress epProgress({
        required String episodeId,
        String? seriesId,
        required DateTime updatedAt,
      }) => EpisodeProgress(
        profileId: 'p1',
        episodeId: episodeId,
        seriesId: seriesId,
        positionSeconds: 60,
        completed: false,
        updatedAt: updatedAt,
      );

      test('a known seriesId fetches that series and nothing else', () async {
        final big = bigCatalog(20);
        final series = _FakeSeries(big.details);
        final uc = ResolveContinueWatchingUseCase(
          progressRepo: _FakeProgress([
            epProgress(
              episodeId: 'series-7-e1',
              seriesId: 'series-7',
              updatedAt: DateTime(2026, 5, 6),
            ),
          ]),
          catalogRepo: _FakeCatalog(big.catalog),
          seriesRepo: series,
          logger: _logger,
        );

        final result = await uc.execute('p1');

        expect(result, hasLength(1));
        expect(series.findByIdCalls, ['series-7']);
      });

      test('several entries on one series fetch it once', () async {
        final big = bigCatalog(20);
        final series = _FakeSeries(big.details);
        final uc = ResolveContinueWatchingUseCase(
          progressRepo: _FakeProgress([
            epProgress(
              episodeId: 'series-3-e1',
              seriesId: 'series-3',
              updatedAt: DateTime(2026, 5, 6),
            ),
            epProgress(
              episodeId: 'series-3-e1',
              seriesId: 'series-3',
              updatedAt: DateTime(2026, 5, 5),
            ),
          ]),
          catalogRepo: _FakeCatalog(big.catalog),
          seriesRepo: series,
          logger: _logger,
        );

        final result = await uc.execute('p1');

        // Dedup by series still collapses them to one card.
        expect(result, hasLength(1));
        expect(series.findByIdCalls, ['series-3']);
      });

      test(
        'without a seriesId the catalog is walked once, not once per entry',
        () async {
          final big = bigCatalog(20);
          final series = _FakeSeries(big.details);
          final uc = ResolveContinueWatchingUseCase(
            progressRepo: _FakeProgress([
              epProgress(
                episodeId: 'series-2-e1',
                updatedAt: DateTime(2026, 5, 6),
              ),
              epProgress(
                episodeId: 'series-9-e1',
                updatedAt: DateTime(2026, 5, 5),
              ),
              epProgress(
                episodeId: 'series-15-e1',
                updatedAt: DateTime(2026, 5, 4),
              ),
            ]),
            catalogRepo: _FakeCatalog(big.catalog),
            seriesRepo: series,
            logger: _logger,
          );

          final result = await uc.execute('p1');

          expect(result, hasLength(3));
          // The old implementation restarted a full sequential walk per
          // entry: 3 × 20 = up to 60 calls. One shared pass caps it at
          // the catalog size, and no series is ever fetched twice.
          expect(series.findByIdCalls, hasLength(20));
          expect(series.findByIdCalls.toSet(), hasLength(20));
        },
      );

      test('supplied catalog and progresses are not re-fetched', () async {
        final big = bigCatalog(5);
        final catalog = _FakeCatalog(big.catalog);
        final progressRepo = _FakeProgress([]);
        final uc = ResolveContinueWatchingUseCase(
          progressRepo: progressRepo,
          catalogRepo: catalog,
          seriesRepo: _FakeSeries(big.details),
          logger: _logger,
        );

        final result = await uc.execute(
          'p1',
          catalog: big.catalog,
          progresses: [
            epProgress(
              episodeId: 'series-1-e1',
              seriesId: 'series-1',
              updatedAt: DateTime(2026, 5, 6),
            ),
          ],
        );

        expect(result, hasLength(1));
        expect(catalog.listCalls, 0);
      });

      test('the fallback walk happens once per session, not per load', () async {
        final big = bigCatalog(20);
        final series = _FakeSeries(big.details);
        final progress = epProgress(
          episodeId: 'series-6-e1',
          updatedAt: DateTime(2026, 5, 6),
        );
        final uc = ResolveContinueWatchingUseCase(
          progressRepo: _FakeProgress([progress]),
          catalogRepo: _FakeCatalog(big.catalog),
          seriesRepo: series,
          logger: _logger,
        );

        await uc.execute('p1');
        expect(series.findByIdCalls, hasLength(20));

        // Second home load on the same instance: the parent learned by
        // the first walk is reused, so only that series is re-fetched.
        series.findByIdCalls.clear();
        final result = await uc.execute('p1');

        expect(result, hasLength(1));
        expect(series.findByIdCalls, ['series-6']);
      });

      test('a stale seriesId drops the entry instead of walking', () async {
        final big = bigCatalog(20);
        final series = _FakeSeries(big.details);
        final uc = ResolveContinueWatchingUseCase(
          progressRepo: _FakeProgress([
            epProgress(
              episodeId: 'series-4-e1',
              seriesId: 'gone',
              updatedAt: DateTime(2026, 5, 6),
            ),
          ]),
          catalogRepo: _FakeCatalog(big.catalog),
          seriesRepo: series,
          logger: _logger,
        );

        final result = await uc.execute('p1');

        expect(result, isEmpty);
        expect(series.findByIdCalls, ['gone']);
      });
    });
  });
}
