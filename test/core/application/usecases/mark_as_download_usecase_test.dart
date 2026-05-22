import 'package:flutter_test/flutter_test.dart';
import 'package:kidflix/core/application/usecases/mark_as_cache.usecase.dart';
import 'package:kidflix/core/application/usecases/mark_as_download.usecase.dart';
import 'package:kidflix/core/domain/model/download_inventory_record.dart';
import 'package:kidflix/core/domain/model/download_kind.dart';
import 'package:kidflix/core/domain/model/episode_download.dart';
import 'package:kidflix/core/domain/model/movie_download.dart';
import 'package:kidflix/core/domain/services/download.repository.dart';

void main() {
  test(
    'MarkAsDownloadUseCase dispatches to setMovieKind for a movie',
    () async {
      final fake = _FakeRepo();
      final useCase = MarkAsDownloadUseCase(fake);
      await useCase.execute(mediaId: 'abc', isEpisode: false);
      expect(fake.movieKindCalls, [('abc', DownloadKind.download)]);
      expect(fake.episodeKindCalls, isEmpty);
    },
  );

  test(
    'MarkAsDownloadUseCase dispatches to setEpisodeKind for an episode',
    () async {
      final fake = _FakeRepo();
      final useCase = MarkAsDownloadUseCase(fake);
      await useCase.execute(mediaId: 'pingu-s01e04', isEpisode: true);
      expect(fake.episodeKindCalls, [('pingu-s01e04', DownloadKind.download)]);
      expect(fake.movieKindCalls, isEmpty);
    },
  );

  test(
    'MarkAsCacheUseCase dispatches to the right method with cache kind',
    () async {
      final fake = _FakeRepo();
      final useCase = MarkAsCacheUseCase(fake);
      await useCase.execute(mediaId: 'abc', isEpisode: false);
      await useCase.execute(mediaId: 'pingu', isEpisode: true);
      expect(fake.movieKindCalls, [('abc', DownloadKind.cache)]);
      expect(fake.episodeKindCalls, [('pingu', DownloadKind.cache)]);
    },
  );
}

class _FakeRepo implements DownloadRepository {
  final movieKindCalls = <(String, DownloadKind)>[];
  final episodeKindCalls = <(String, DownloadKind)>[];

  @override
  Future<void> setMovieKind(String movieId, DownloadKind kind) async {
    movieKindCalls.add((movieId, kind));
  }

  @override
  Future<void> setEpisodeKind(String episodeId, DownloadKind kind) async {
    episodeKindCalls.add((episodeId, kind));
  }

  @override
  noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());

  // Cast hints — the analyzer needs explicit overrides on contract methods.
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
  Future<List<DownloadInventoryRecord>> listAll() => throw UnimplementedError();
  @override
  Future<int> totalBytesOnDisk() => throw UnimplementedError();
  @override
  Future<void> markPlayed({required String mediaId, required bool isEpisode}) =>
      throw UnimplementedError();
}
