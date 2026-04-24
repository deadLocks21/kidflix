import 'package:kidflix/core/domain/model/movie_download.dart';

/// UI-facing projection of [DownloadStatus].
enum DownloadStatusDto {
  notStarted,
  downloading,
  readyToPlay,
  complete,
  failed,
  cancelled,
}

/// UI-facing projection of [MovieDownload].
///
/// Keeps the same field structure as the domain model, plus derived
/// getters used by the UI (`isPlayable`, `progressFraction`).
class MovieDownloadDto {
  final String movieId;
  final DownloadStatusDto status;
  final int bytesReceived;
  final int? bytesTotal;
  final String? localPath;
  final String? errorMessage;
  final DateTime updatedAt;

  const MovieDownloadDto({
    required this.movieId,
    required this.status,
    required this.bytesReceived,
    required this.updatedAt,
    this.bytesTotal,
    this.localPath,
    this.errorMessage,
  });

  factory MovieDownloadDto.fromDomain(MovieDownload download) =>
      MovieDownloadDto(
        movieId: download.movieId,
        status: _mapStatus(download.status),
        bytesReceived: download.bytesReceived,
        bytesTotal: download.bytesTotal,
        localPath: download.localPath,
        errorMessage: download.errorMessage,
        updatedAt: download.updatedAt,
      );

  /// `true` when the local file is usable by the player.
  bool get isPlayable =>
      status == DownloadStatusDto.readyToPlay ||
      status == DownloadStatusDto.complete;

  /// Fraction in `[0, 1]` when [bytesTotal] is known, `null` otherwise.
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
