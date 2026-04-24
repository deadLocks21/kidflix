import 'package:flutter_test/flutter_test.dart';
import 'package:kidflix/core/application/dtos/movie_download.dto.dart';
import 'package:kidflix/core/application/usecases/start_movie_download.usecase.dart';
import 'package:kidflix/core/domain/model/movie_download.dart';
import 'package:kidflix/core/domain/services/download.repository.dart';

void main() {
  test('maps every domain event to its DTO in order', () async {
    final fake = _FakeRepo();
    final useCase = StartMovieDownloadUseCase(fake);
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
  Stream<MovieDownload> download(String movieId) async* {
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
  Future<MovieDownload?> findByMovieId(String movieId) async => null;

  @override
  Future<void> cancel(String movieId) async {}

  @override
  Future<void> delete(String movieId) async {}
}
