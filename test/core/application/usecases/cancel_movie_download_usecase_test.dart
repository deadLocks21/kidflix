import 'package:flutter_test/flutter_test.dart';
import 'package:kidflix/core/application/usecases/cancel_movie_download.usecase.dart';
import 'package:kidflix/core/domain/model/movie_download.dart';
import 'package:kidflix/core/domain/services/download.repository.dart';

void main() {
  test('delegates to repository.cancel', () async {
    final fake = _FakeRepo();
    final useCase = CancelMovieDownloadUseCase(fake);
    await useCase.execute('abc');
    expect(fake.cancelledIds, ['abc']);
  });
}

class _FakeRepo implements DownloadRepository {
  final cancelledIds = <String>[];

  @override
  Future<void> cancel(String movieId) async {
    cancelledIds.add(movieId);
  }

  @override
  Future<MovieDownload?> findByMovieId(String movieId) async => null;

  @override
  Stream<MovieDownload> download(String movieId) => const Stream.empty();

  @override
  Future<void> delete(String movieId) async {}
}
