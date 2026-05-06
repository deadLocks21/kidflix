import 'package:flutter_test/flutter_test.dart';
import 'package:kidflix/core/application/dtos/movie_download.dto.dart';
import 'package:kidflix/core/application/usecases/start_episode_download.usecase.dart';
import 'package:kidflix/core/domain/model/episode_download.dart';
import 'package:kidflix/core/domain/model/movie_download.dart';
import 'package:kidflix/core/domain/services/download.repository.dart';

void main() {
  test('maps every domain event to its DTO in order', () async {
    final fake = _FakeRepo();
    final useCase = StartEpisodeDownloadUseCase(fake);
    final events = await useCase.execute('ep-1').toList();

    expect(events, hasLength(3));
    expect(events[0].status, DownloadStatusDto.downloading);
    expect(events[0].bytesReceived, 500_000);
    expect(events[1].status, DownloadStatusDto.readyToPlay);
    expect(events[2].status, DownloadStatusDto.complete);
    expect(events.every((e) => e.episodeId == 'ep-1'), isTrue);
  });
}

class _FakeRepo implements DownloadRepository {
  @override
  Stream<EpisodeDownload> downloadEpisode(String episodeId) async* {
    final now = DateTime.now();
    yield EpisodeDownload(
      episodeId: episodeId,
      status: DownloadStatus.downloading,
      bytesReceived: 500_000,
      bytesTotal: 10_000_000,
      updatedAt: now,
    );
    yield EpisodeDownload(
      episodeId: episodeId,
      status: DownloadStatus.readyToPlay,
      bytesReceived: 2_500_000,
      bytesTotal: 10_000_000,
      localPath: '/tmp/$episodeId.mp4.partial',
      updatedAt: now,
    );
    yield EpisodeDownload(
      episodeId: episodeId,
      status: DownloadStatus.complete,
      bytesReceived: 10_000_000,
      bytesTotal: 10_000_000,
      localPath: '/tmp/$episodeId.mp4',
      updatedAt: now,
    );
  }

  @override
  Future<EpisodeDownload?> findForEpisode(String episodeId) async => null;
  @override
  Future<void> cancelEpisode(String episodeId) async {}
  @override
  Future<void> deleteEpisode(String episodeId) async {}

  @override
  Stream<MovieDownload> downloadMovie(String movieId) => const Stream.empty();
  @override
  Future<MovieDownload?> findForMovie(String movieId) async => null;
  @override
  Future<void> cancelMovie(String movieId) async {}
  @override
  Future<void> deleteMovie(String movieId) async {}
}
