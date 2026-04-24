import 'package:flutter_test/flutter_test.dart';
import 'package:kidflix/core/application/dtos/movie_download.dto.dart';
import 'package:kidflix/core/application/usecases/find_movie_download.usecase.dart';
import 'package:kidflix/core/domain/model/movie_download.dart';
import 'package:kidflix/core/domain/services/download.repository.dart';

void main() {
  test('returns null when repo returns null', () async {
    final useCase = FindMovieDownloadUseCase(_FakeRepo(value: null));
    expect(await useCase.execute('abc'), isNull);
  });

  test('returns DTO mapped from domain when repo returns a download', () async {
    final domain = MovieDownload(
      movieId: 'abc',
      status: DownloadStatus.complete,
      bytesReceived: 1_000,
      bytesTotal: 1_000,
      localPath: '/tmp/abc.mp4',
      updatedAt: DateTime(2026, 4, 24),
    );
    final useCase = FindMovieDownloadUseCase(_FakeRepo(value: domain));
    final dto = await useCase.execute('abc');
    expect(dto, isNotNull);
    expect(dto!.status, DownloadStatusDto.complete);
    expect(dto.movieId, 'abc');
    expect(dto.localPath, '/tmp/abc.mp4');
  });
}

class _FakeRepo implements DownloadRepository {
  _FakeRepo({this.value});

  final MovieDownload? value;

  @override
  Future<MovieDownload?> findByMovieId(String movieId) async => value;

  @override
  Stream<MovieDownload> download(String movieId) => const Stream.empty();

  @override
  Future<void> cancel(String movieId) async {}

  @override
  Future<void> delete(String movieId) async {}
}
