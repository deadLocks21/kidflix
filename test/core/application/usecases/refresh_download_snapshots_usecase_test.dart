import 'package:flutter_test/flutter_test.dart';
import 'package:kidflix/core/application/usecases/refresh_download_snapshots.usecase.dart';
import 'package:kidflix/core/domain/model/download_kind.dart';
import 'package:kidflix/core/domain/model/media.dart';
import 'package:kidflix/core/domain/services/catalog.repository.dart';
import 'package:kidflix/core/domain/services/download.repository.dart';
import 'package:kidflix/core/domain/services/series.repository.dart';
import 'package:kidflix/infrastructure/downloads/download_manifest_entry.dart';
import 'package:kidflix/infrastructure/downloads/manifest_store.dart';

/// Counts the network the pass actually performs. The whole point of
/// this use case's contract is that a healthy manifest costs zero
/// requests — it runs after every home build.
class _CountingCatalog implements CatalogRepository {
  int listCalls = 0;
  int listForProfileCalls = 0;

  @override
  Future<List<CatalogItem>> listCatalog() async {
    listCalls++;
    return const [];
  }

  @override
  Future<List<CatalogItem>> listCatalogForProfile(String profileId) async {
    listForProfileCalls++;
    return const [];
  }

  @override
  Future<List<CatalogItem>> searchCatalog({required String query}) async =>
      const [];
}

class _CountingSeries implements SeriesRepository {
  final List<String> findByIdCalls = [];

  @override
  Future<Series> findById(String seriesId) async {
    findByIdCalls.add(seriesId);
    throw StateError('not needed for these assertions');
  }

  @override
  Future<Series> findByIdForProfile(String seriesId, String profileId) =>
      findById(seriesId);
}

class _NoopDownloads implements DownloadRepository {
  @override
  Future<void> cacheMediaMetadata({
    required String mediaId,
    required bool isEpisode,
    required String title,
    String? posterUrl,
    String? parentSeriesTitle,
    String? originalTitle,
    int? year,
    int? durationSeconds,
    String? ageCategory,
    String? synopsis,
    String? tagline,
    String? backdropUrl,
    String? logoUrl,
    List<String>? genres,
    List<String>? director,
    List<CachedCastMember>? topCast,
    String? seriesId,
    int? seasonNumber,
    int? episodeNumber,
  }) async {}

  @override
  Future<void> cacheSeriesMetadata({
    required String seriesId,
    required String title,
    String? posterUrl,
    String? originalTitle,
    int? year,
    String? ageCategory,
    String? synopsis,
    String? tagline,
    String? backdropUrl,
    String? logoUrl,
    List<String>? genres,
    List<String>? director,
    List<CachedCastMember>? topCast,
    int? seasonsCount,
    int? episodesCount,
  }) async {}

  @override
  noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not used here');
}

class _StaticManifest implements DownloadManifestStore {
  _StaticManifest(this._records);
  final List<DownloadManifestRecord> _records;

  @override
  Future<List<DownloadManifestRecord>> listAll() async => _records;

  @override
  noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not used here');
}

DownloadManifestRecord _movie(String id, {required bool complete}) =>
    DownloadManifestRecord(
      mediaId: id,
      kind: ManifestEntryKind.movie,
      entry: DownloadManifestEntry(
        kind: DownloadKind.download,
        completedAt: DateTime.utc(2026, 5, 1),
        cachedTitle: complete ? 'Nemo' : null,
        cachedAgeCategory: complete ? 'enfant' : null,
        cachedDurationSeconds: complete ? 6000 : null,
      ),
    );

DownloadManifestRecord _episode(
  String id, {
  required String seriesId,
  required bool complete,
}) => DownloadManifestRecord(
  mediaId: id,
  kind: ManifestEntryKind.episode,
  entry: DownloadManifestEntry(
    kind: DownloadKind.download,
    completedAt: DateTime.utc(2026, 5, 1),
    cachedTitle: complete ? 'E1 · Pilote' : null,
    cachedSeriesId: seriesId,
    cachedSeasonNumber: complete ? 1 : null,
    cachedEpisodeNumber: complete ? 1 : null,
    cachedAgeCategory: complete ? 'enfant' : null,
    cachedDurationSeconds: complete ? 300 : null,
  ),
);

DownloadManifestRecord _series(String id, {required bool complete}) =>
    DownloadManifestRecord(
      mediaId: id,
      kind: ManifestEntryKind.series,
      entry: DownloadManifestEntry(
        kind: DownloadKind.download,
        cachedTitle: complete ? 'Pingu' : null,
        cachedAgeCategory: complete ? 'enfant' : null,
      ),
    );

({
  RefreshDownloadSnapshotsUseCase useCase,
  _CountingCatalog catalog,
  _CountingSeries series,
})
build(List<DownloadManifestRecord> records) {
  final catalog = _CountingCatalog();
  final series = _CountingSeries();
  return (
    useCase: RefreshDownloadSnapshotsUseCase(
      catalog: catalog,
      series: series,
      downloads: _NoopDownloads(),
      manifest: _StaticManifest(records),
    ),
    catalog: catalog,
    series: series,
  );
}

void main() {
  group('RefreshDownloadSnapshotsUseCase', () {
    test('un manifeste vide ne déclenche aucun réseau', () async {
      final ctx = build([]);

      await ctx.useCase.execute(profileIds: ['p1', 'p2']);

      expect(ctx.catalog.listForProfileCalls, 0);
      expect(ctx.series.findByIdCalls, isEmpty);
    });

    test('un manifeste déjà complet ne déclenche aucun réseau', () async {
      final ctx = build([
        _movie('m1', complete: true),
        _series('s1', complete: true),
        _episode('e1', seriesId: 's1', complete: true),
      ]);

      await ctx.useCase.execute(profileIds: ['p1', 'p2', 'p3']);

      // Le cas courant : la passe tourne après CHAQUE build de la home.
      // Elle doit coûter zéro requête.
      expect(ctx.catalog.listForProfileCalls, 0);
      expect(ctx.catalog.listCalls, 0);
      expect(ctx.series.findByIdCalls, isEmpty);
    });

    test(
      'aucun catalogue chargé quand seules des séries sont à soigner',
      () async {
        final ctx = build([
          _movie('m1', complete: true),
          _series('s1', complete: false),
          _episode('e1', seriesId: 's1', complete: true),
        ]);

        await ctx.useCase.execute(profileIds: ['p1', 'p2', 'p3']);

        // Le catalogue ne sert qu'aux films : une série passe forcément
        // par findById, puisqu'un item de catalogue ne porte pas ses
        // saisons.
        expect(ctx.catalog.listForProfileCalls, 0);
        expect(ctx.series.findByIdCalls, ['s1']);
      },
    );

    test('un film incomplet charge le catalogue de chaque profil', () async {
      final ctx = build([_movie('m1', complete: false)]);

      await ctx.useCase.execute(profileIds: ['p1', 'p2']);

      expect(ctx.catalog.listForProfileCalls, 2);
    });

    test('une passe identique n\'est pas rejouée dans la session', () async {
      final ctx = build([
        _series('s1', complete: false),
        _episode('e1', seriesId: 's1', complete: true),
      ]);

      await ctx.useCase.execute(profileIds: ['p1']);
      expect(ctx.series.findByIdCalls, ['s1']);

      // La home se reconstruit plusieurs fois pendant que les favoris,
      // les déjà-vu et l'inventaire se stabilisent. Rejouer le même
      // travail ne ferait que concurrencer l'écran attendu.
      await ctx.useCase.execute(profileIds: ['p1']);
      await ctx.useCase.execute(profileIds: ['p1']);

      expect(ctx.series.findByIdCalls, ['s1']);
    });

    test('un épisode sans seriesId connu est ignoré, pas deviné', () async {
      final ctx = build([
        DownloadManifestRecord(
          mediaId: 'e-orphelin',
          kind: ManifestEntryKind.episode,
          entry: DownloadManifestEntry(
            kind: DownloadKind.download,
            completedAt: DateTime.utc(2026, 5, 1),
          ),
        ),
      ]);

      await ctx.useCase.execute(profileIds: ['p1']);

      expect(ctx.series.findByIdCalls, isEmpty);
      expect(ctx.catalog.listForProfileCalls, 0);
    });
  });
}
