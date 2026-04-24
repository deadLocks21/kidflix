import 'package:flutter_test/flutter_test.dart';
import 'package:kidflix/core/application/usecases/delete_movie_download.usecase.dart';
import 'package:kidflix/core/domain/model/movie_download.dart';
import 'package:kidflix/core/domain/services/download.repository.dart';

void main() {
  test('delegates to repository.delete', () async {
    final fake = _FakeRepo();
    final useCase = DeleteMovieDownloadUseCase(fake);
    await useCase.execute('abc');
    expect(fake.deletedIds, ['abc']);
  });
}

class _FakeRepo implements DownloadRepository {
  final deletedIds = <String>[];

  @override
  Future<void> delete(String movieId) async {
    deletedIds.add(movieId);
  }

  @override
  Future<MovieDownload?> findByMovieId(String movieId) async => null;

  @override
  Stream<MovieDownload> download(String movieId) => const Stream.empty();

  @override
  Future<void> cancel(String movieId) async {}
}
