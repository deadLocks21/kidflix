/// Progression states a movie download goes through, from never-started to
/// terminal success or failure.
///
/// Ordering reflects the typical lifecycle:
/// `notStarted → downloading → readyToPlay → complete`, with `failed` or
/// `cancelled` as terminal detours. `notStarted` is only ever returned by
/// [MovieDownload] snapshots from `findByMovieId`; the download stream
/// itself never emits it.
enum DownloadStatus {
  notStarted,
  downloading,
  readyToPlay,
  complete,
  failed,
  cancelled,
}

/// Immutable snapshot of a movie download.
///
/// Each [MovieDownload] instance captures the download state at a single
/// point in time. The `DownloadRepository.download` stream emits a
/// sequence of these snapshots as bytes arrive and as the status
/// transitions between [DownloadStatus] values.
///
/// Equality uses the tuple `(movieId, status, bytesReceived, updatedAt)`
/// so that consecutive identical snapshots deduplicate naturally in
/// Riverpod / StreamBuilder contexts.
class MovieDownload {
  final String movieId;
  final DownloadStatus status;
  final int bytesReceived;
  final int? bytesTotal;
  final String? localPath;
  final String? errorMessage;
  final DateTime updatedAt;

  const MovieDownload({
    required this.movieId,
    required this.status,
    required this.bytesReceived,
    required this.updatedAt,
    this.bytesTotal,
    this.localPath,
    this.errorMessage,
  });

  /// `true` when [status] allows the player to open [localPath] — either
  /// the ready threshold has been reached or the download is complete.
  bool get isPlayable =>
      status == DownloadStatus.readyToPlay ||
      status == DownloadStatus.complete;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MovieDownload &&
          other.movieId == movieId &&
          other.status == status &&
          other.bytesReceived == bytesReceived &&
          other.updatedAt == updatedAt);

  @override
  int get hashCode =>
      Object.hash(movieId, status, bytesReceived, updatedAt);

  @override
  String toString() =>
      'MovieDownload(movieId: $movieId, status: $status, '
      'bytesReceived: $bytesReceived, bytesTotal: $bytesTotal)';
}
