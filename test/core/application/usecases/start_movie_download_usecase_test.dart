import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kidflix/core/application/dtos/movie_download.dto.dart';
import 'package:kidflix/core/application/services/logger_application.service.dart';
import 'package:kidflix/core/application/usecases/start_movie_download.usecase.dart';
import 'package:kidflix/core/domain/model/cached_cast_member.dart';
import 'package:kidflix/core/domain/model/download_inventory_record.dart';
import 'package:kidflix/core/domain/model/download_kind.dart';
import 'package:kidflix/core/domain/model/episode_download.dart';
import 'package:kidflix/core/domain/model/movie_download.dart';
import 'package:kidflix/core/domain/services/download.repository.dart';
import 'package:kidflix/infrastructure/downloads/manifest_store.dart';
import 'package:kidflix/infrastructure/logger/in_memory.logger.service.dart';

void main() {
  test('maps every domain event to its DTO in order', () async {
    final fake = _FakeRepo();
    final tempDir = Directory.systemTemp.createTempSync('kidflix-usecase-');
    final useCase = StartMovieDownloadUseCase(
      repository: fake,
      manifest: JsonFileDownloadManifestStore(
        resolveDownloadsDir: () async => tempDir,
      ),
      logger: LoggerApplicationService(InMemoryLoggerService()),
    );
    final events = await useCase.execute('abc').toList();

    expect(events, hasLength(3));
    expect(events[0].status, DownloadStatusDto.downloading);
    expect(events[0].bytesReceived, 500_000);
    expect(events[1].status, DownloadStatusDto.readyToPlay);
    expect(events[2].status, DownloadStatusDto.complete);
    expect(events.every((e) => e.movieId == 'abc'), isTrue);
  });
}

class _FakeRepo implements DownloadRepository {
  @override
  Stream<MovieDownload> downloadMovie(String movieId) async* {
    final now = DateTime.now();
    yield MovieDownload(
      movieId: movieId,
      status: DownloadStatus.downloading,
      bytesReceived: 500_000,
      bytesTotal: 10_000_000,
      updatedAt: now,
    );
    yield MovieDownload(
      movieId: movieId,
      status: DownloadStatus.readyToPlay,
      bytesReceived: 2_500_000,
      bytesTotal: 10_000_000,
      localPath: '/tmp/$movieId.mp4.partial',
      updatedAt: now,
    );
    yield MovieDownload(
      movieId: movieId,
      status: DownloadStatus.complete,
      bytesReceived: 10_000_000,
      bytesTotal: 10_000_000,
      localPath: '/tmp/$movieId.mp4',
      updatedAt: now,
    );
  }

  @override
  Future<MovieDownload?> findForMovie(String movieId) async => null;

  @override
  Future<void> cancelMovie(String movieId) async {}

  @override
  Future<void> deleteMovie(String movieId) async {}

  @override
  Future<EpisodeDownload?> findForEpisode(String episodeId) async => null;

  @override
  Stream<EpisodeDownload> downloadEpisode(String episodeId) =>
      const Stream.empty();

  @override
  Future<void> cancelEpisode(String episodeId) async {}

  @override
  Future<void> deleteEpisode(String episodeId) async {}

  @override
  Future<void> deleteAll() async {}

  @override
  Future<List<DownloadInventoryRecord>> listAll() async => const [];

  @override
  Future<int> totalBytesOnDisk() async => 0;

  @override
  Future<void> setMovieKind(String movieId, DownloadKind kind) async {}

  @override
  Future<void> setEpisodeKind(String episodeId, DownloadKind kind) async {}

  @override
  Future<void> markPlayed({
    required String mediaId,
    required bool isEpisode,
  }) async {}

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
}
