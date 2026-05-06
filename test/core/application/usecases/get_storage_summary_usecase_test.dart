import 'package:flutter_test/flutter_test.dart';
import 'package:kidflix/core/application/usecases/get_storage_summary.usecase.dart';
import 'package:kidflix/core/domain/model/download_inventory_record.dart';
import 'package:kidflix/core/domain/model/download_kind.dart';
import 'package:kidflix/core/domain/model/episode_download.dart';
import 'package:kidflix/core/domain/model/movie_download.dart';
import 'package:kidflix/core/domain/services/device_storage_probe.dart';
import 'package:kidflix/core/domain/services/download.repository.dart';

void main() {
  test('aggregates probe and inventory partition counts', () async {
    final useCase = GetStorageSummaryUseCase(
      probe: _StubProbe(appBytes: 4_509_715_660, freeBytes: 12_884_901_888),
      repository: _StubRepo([
        _record('a', kind: DownloadKind.download),
        _record('b', kind: DownloadKind.download),
        _record('c', kind: DownloadKind.cache),
        _record('d', kind: DownloadKind.cache),
        _record('e', kind: DownloadKind.cache),
      ]),
    );

    final summary = await useCase.execute();

    expect(summary.appDownloadsBytes, equals(4_509_715_660));
    expect(summary.deviceFreeBytes, equals(12_884_901_888));
    expect(summary.downloadsCount, equals(2));
    expect(summary.cacheCount, equals(3));
  });

  test('null deviceFreeBytes is propagated verbatim', () async {
    final useCase = GetStorageSummaryUseCase(
      probe: _StubProbe(appBytes: 0, freeBytes: null),
      repository: _StubRepo(const []),
    );
    final summary = await useCase.execute();
    expect(summary.deviceFreeBytes, isNull);
  });

  test('empty inventory yields zero counts', () async {
    final useCase = GetStorageSummaryUseCase(
      probe: _StubProbe(appBytes: 0, freeBytes: 1000),
      repository: _StubRepo(const []),
    );
    final summary = await useCase.execute();
    expect(summary.downloadsCount, equals(0));
    expect(summary.cacheCount, equals(0));
  });
}

DownloadInventoryRecord _record(String id, {required DownloadKind kind}) =>
    DownloadInventoryRecord(
      mediaId: id,
      isEpisode: false,
      bytesOnDisk: 100,
      kind: kind,
    );

class _StubProbe implements DeviceStorageProbe {
  final int appBytes;
  final int? freeBytes;
  _StubProbe({required this.appBytes, required this.freeBytes});

  @override
  Future<int> appDownloadsBytes() async => appBytes;

  @override
  Future<int?> deviceFreeBytes() async => freeBytes;
}

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
