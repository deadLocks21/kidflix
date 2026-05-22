import 'package:flutter_test/flutter_test.dart';
import 'package:kidflix/core/application/services/logger_application.service.dart';
import 'package:kidflix/core/application/usecases/cancel_movie_download.usecase.dart';
import 'package:kidflix/core/domain/model/cached_cast_member.dart';
import 'package:kidflix/core/domain/model/download_inventory_record.dart';
import 'package:kidflix/core/domain/model/download_kind.dart';
import 'package:kidflix/core/domain/model/episode_download.dart';
import 'package:kidflix/core/domain/model/movie_download.dart';
import 'package:kidflix/core/domain/services/download.repository.dart';
import 'package:kidflix/infrastructure/logger/in_memory.logger.service.dart';

void main() {
  test('delegates to repository.cancelMovie', () async {
    final fake = _FakeRepo();
    final useCase = CancelMovieDownloadUseCase(
      fake,
      LoggerApplicationService(InMemoryLoggerService()),
    );
    await useCase.execute('abc');
    expect(fake.cancelledIds, ['abc']);
  });
}

class _FakeRepo implements DownloadRepository {
  final cancelledIds = <String>[];

  @override
  Future<void> cancelMovie(String movieId) async {
    cancelledIds.add(movieId);
  }

  @override
  Future<MovieDownload?> findForMovie(String movieId) async => null;

  @override
  Stream<MovieDownload> downloadMovie(String movieId) => const Stream.empty();

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
