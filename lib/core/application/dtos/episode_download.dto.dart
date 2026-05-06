import 'package:kidflix/core/application/dtos/movie_download.dto.dart';
import 'package:kidflix/core/domain/model/episode_download.dart';
import 'package:kidflix/core/domain/model/movie_download.dart';

/// UI-facing projection of [EpisodeDownload]. Mirrors [MovieDownloadDto]
/// keyed on `episodeId` instead of `movieId`. Reuses the
/// [DownloadStatusDto] enum from `movie_download.dto.dart`.
class EpisodeDownloadDto {
  final String episodeId;
  final DownloadStatusDto status;
  final int bytesReceived;
  final int? bytesTotal;
  final String? localPath;
  final String? errorMessage;
  final DateTime updatedAt;

  const EpisodeDownloadDto({
    required this.episodeId,
    required this.status,
    required this.bytesReceived,
    required this.updatedAt,
    this.bytesTotal,
    this.localPath,
    this.errorMessage,
  });

  factory EpisodeDownloadDto.fromDomain(EpisodeDownload download) =>
      EpisodeDownloadDto(
        episodeId: download.episodeId,
        status: _mapStatus(download.status),
        bytesReceived: download.bytesReceived,
        bytesTotal: download.bytesTotal,
        localPath: download.localPath,
        errorMessage: download.errorMessage,
        updatedAt: download.updatedAt,
      );

  bool get isPlayable =>
      status == DownloadStatusDto.readyToPlay ||
      status == DownloadStatusDto.complete;

  double? get progressFraction {
    final total = bytesTotal;
    if (total == null || total == 0) return null;
    final ratio = bytesReceived / total;
    if (ratio < 0) return 0;
    if (ratio > 1) return 1;
    return ratio;
  }

  static DownloadStatusDto _mapStatus(DownloadStatus status) => switch (status) {
    DownloadStatus.notStarted => DownloadStatusDto.notStarted,
    DownloadStatus.downloading => DownloadStatusDto.downloading,
    DownloadStatus.readyToPlay => DownloadStatusDto.readyToPlay,
    DownloadStatus.complete => DownloadStatusDto.complete,
    DownloadStatus.failed => DownloadStatusDto.failed,
    DownloadStatus.cancelled => DownloadStatusDto.cancelled,
  };
}
