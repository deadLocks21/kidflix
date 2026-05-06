import 'package:flutter_test/flutter_test.dart';
import 'package:kidflix/core/application/usecases/list_downloads.usecase.dart';
import 'package:kidflix/core/domain/model/download_entry.dart';
import 'package:kidflix/core/domain/model/download_inventory_record.dart';
import 'package:kidflix/core/domain/model/download_kind.dart';
import 'package:kidflix/core/domain/model/episode_download.dart';
import 'package:kidflix/core/domain/model/media.dart';
import 'package:kidflix/core/domain/model/profile.dart' show AgeCategory;
import 'package:kidflix/core/domain/model/movie_download.dart';
import 'package:kidflix/core/domain/services/catalog.repository.dart';
import 'package:kidflix/core/domain/services/download.repository.dart';
import 'package:kidflix/core/domain/services/series.repository.dart';

void main() {
  test('partitions by kind and decorates movie entries from catalog', () async {
    final repo = _StubRepo([
      _record('movie-a', false, kind: DownloadKind.download),
      _record('movie-b', false, kind: DownloadKind.cache),
    ]);
    final catalog = _StubCatalog([
      _movie(id: 'movie-a', title: 'Le Roi Lion', poster: 'roi.jpg'),
      _movie(id: 'movie-b', title: 'Toy Story', poster: null),
    ]);
    final useCase = ListDownloadsUseCase(
      repository: repo,
      catalog: catalog,
      series: _NoopSeries(),
    );

    final inv = await useCase.execute();
    expect(inv.downloads.length, equals(1));
    expect(inv.cache.length, equals(1));
    expect(inv.downloads.first.displayTitle, equals('Le Roi Lion'));
    expect(inv.downloads.first.displayPosterUrl, equals('roi.jpg'));
    expect(inv.cache.first.displayTitle, equals('Toy Story'));
  });

  test('falls back to "Vidéo inconnue" when catalog lookup misses', () async {
    final repo = _StubRepo([
      _record('orphan', false, kind: DownloadKind.cache),
    ]);
    final catalog = _StubCatalog(const []);
    final useCase = ListDownloadsUseCase(
      repository: repo,
      catalog: catalog,
      series: _NoopSeries(),
    );

    final inv = await useCase.execute();
    expect(inv.cache.length, equals(1));
    expect(inv.cache.first.displayTitle, startsWith(unknownVideoTitle));
    expect(inv.cache.first.displayTitle, contains('orphan'));
    expect(inv.cache.first.mediaKind, equals(DownloadMediaKind.movie));
  });

  test('sorts each list by lastPlayedAt descending; nulls go last', () async {
    final repo = _StubRepo([
      _record('a', false,
          kind: DownloadKind.cache, lastPlayed: DateTime.utc(2026, 5, 1)),
      _record('b', false,
          kind: DownloadKind.cache, lastPlayed: DateTime.utc(2026, 5, 4)),
      _record('c', false, kind: DownloadKind.cache, lastPlayed: null),
      _record('d', false,
          kind: DownloadKind.cache, lastPlayed: DateTime.utc(2026, 5, 2)),
    ]);
    final useCase = ListDownloadsUseCase(
      repository: repo,
      catalog: _StubCatalog(const []),
      series: _NoopSeries(),
    );

    final inv = await useCase.execute();
    final order = inv.cache.map((e) => e.mediaId).toList();
    expect(order, equals(['b', 'd', 'a', 'c']));
  });

  test('resolves an episode through its parent series', () async {
    final repo = _StubRepo([
      _record('pingu-s01e04', true, kind: DownloadKind.cache),
    ]);
    final pingu = Series(
      id: 'pingu',
      title: 'Pingu',
      year: 2025,
      synopsis: '',
      ageCategory: AgeCategory.bebe,
      genres: const [],
      director: const [],
      cast: const [],
      addedAt: DateTime.utc(2026, 1, 1),
      seasonsCount: 1,
      episodesCount: 1,
      seasons: [
        Season(
          seasonNumber: 1,
          episodes: [
            Episode(
              id: 'pingu-s01e04',
              seriesId: 'pingu',
              seasonNumber: 1,
              episodeNumber: 4,
              title: 'Pingu skateur',
              duration: const Duration(minutes: 5),
              ageCategory: AgeCategory.bebe,
              addedAt: DateTime.utc(2026, 1, 1),
            ),
          ],
        ),
      ],
    );
    final catalog = _StubCatalog([pingu]);
    final useCase = ListDownloadsUseCase(
      repository: repo,
      catalog: catalog,
      series: _StubSeries({'pingu': pingu}),
    );

    final inv = await useCase.execute();
    expect(inv.cache.length, equals(1));
    expect(inv.cache.first.displayTitle, equals('Pingu skateur'));
    expect(inv.cache.first.parentSeriesTitle, equals('Pingu'));
  });
}

DownloadInventoryRecord _record(
  String id,
  bool isEpisode, {
  required DownloadKind kind,
  DateTime? lastPlayed,
}) =>
    DownloadInventoryRecord(
      mediaId: id,
      isEpisode: isEpisode,
      bytesOnDisk: 100,
      kind: kind,
      lastPlayedAt: lastPlayed,
    );

Movie _movie({
  required String id,
  required String title,
  required String? poster,
}) =>
    Movie(
      id: id,
      title: title,
      year: 2025,
      duration: const Duration(minutes: 90),
      synopsis: '',
      ageCategory: AgeCategory.enfant,
      genres: const [],
      director: const [],
      cast: const [],
      addedAt: DateTime.utc(2026, 1, 1),
      posterUrl: poster,
    );

class _StubRepo implements DownloadRepository {
  final List<DownloadInventoryRecord> inventory;
  _StubRepo(this.inventory);

  @override
  Future<List<DownloadInventoryRecord>> listAll() async => inventory;

  @override
  noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());

  @override
  Future<MovieDownload?> findForMovie(String movieId) =>
      throw UnimplementedError();
  @override
  Stream<MovieDownload> downloadMovie(String movieId) =>
      throw UnimplementedError();
  @override
  Future<void> cancelMovie(String movieId) => throw UnimplementedError();
  @override
  Future<void> deleteMovie(String movieId) => throw UnimplementedError();
  @override
  Future<EpisodeDownload?> findForEpisode(String episodeId) =>
      throw UnimplementedError();
  @override
  Stream<EpisodeDownload> downloadEpisode(String episodeId) =>
      throw UnimplementedError();
  @override
  Future<void> cancelEpisode(String episodeId) => throw UnimplementedError();
  @override
  Future<void> deleteEpisode(String episodeId) => throw UnimplementedError();
  @override
  Future<int> totalBytesOnDisk() => throw UnimplementedError();
  @override
  Future<void> setMovieKind(String movieId, DownloadKind kind) =>
      throw UnimplementedError();
  @override
  Future<void> setEpisodeKind(String episodeId, DownloadKind kind) =>
      throw UnimplementedError();
  @override
  Future<void> markPlayed({
    required String mediaId,
    required bool isEpisode,
  }) =>
      throw UnimplementedError();
}

class _StubCatalog implements CatalogRepository {
  final List<CatalogItem> items;
  _StubCatalog(this.items);

  @override
  Future<List<CatalogItem>> listCatalog() async => items;

  @override
  Future<List<CatalogItem>> searchCatalog({required String query}) async =>
      items;

  @override
  Future<List<CatalogItem>> listCatalogForProfile(String profileId) =>
      listCatalog();
}

class _StubSeries implements SeriesRepository {
  final Map<String, Series> seriesById;
  _StubSeries(this.seriesById);

  @override
  Future<Series> findById(String seriesId) async {
    final s = seriesById[seriesId];
    if (s == null) throw StateError('series $seriesId not found');
    return s;
  }

  @override
  Future<Series> findByIdForProfile(String seriesId, String profileId) =>
      findById(seriesId);
}

class _NoopSeries implements SeriesRepository {
  @override
  Future<Series> findById(String seriesId) async =>
      throw StateError('not stubbed');

  @override
  Future<Series> findByIdForProfile(String seriesId, String profileId) =>
      findById(seriesId);
}
