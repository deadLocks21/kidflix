import 'package:flutter_test/flutter_test.dart';
import 'package:kidflix/core/application/dtos/movie_download.dto.dart';
import 'package:kidflix/core/application/usecases/find_movie_download.usecase.dart';
import 'package:kidflix/core/domain/model/cached_cast_member.dart';
import 'package:kidflix/core/domain/model/download_inventory_record.dart';
import 'package:kidflix/core/domain/model/download_kind.dart';
import 'package:kidflix/core/domain/model/episode_download.dart';
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
  Future<MovieDownload?> findForMovie(String movieId) async => value;

  @override
  Stream<MovieDownload> downloadMovie(String movieId) => const Stream.empty();

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
