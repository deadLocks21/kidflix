import 'package:kidflix/core/domain/model/download_kind.dart';
import 'package:kidflix/core/domain/model/movie_download.dart';

/// Immutable snapshot of an episode download.
///
/// Mirror of [MovieDownload] keyed on [episodeId] instead of `movieId`.
/// Reuses the [DownloadStatus] enum from `movie_download.dart` — there is
/// no separate enum, the lifecycle is identical.
///
/// `MovieDownload` and `EpisodeDownload` are **siblings without a sealed
/// parent** (cf. `add-series-viewing/design.md` D-7) — the download is a
/// transport concern, not a polymorphic domain. Callers that consume the
/// streams always know statically which kind they handle.
///
/// Equality uses the tuple `(episodeId, status, bytesReceived, updatedAt)`
/// so consecutive identical snapshots deduplicate in Riverpod /
/// StreamBuilder contexts.
class EpisodeDownload {
  final String episodeId;
  final DownloadStatus status;
  final int bytesReceived;
  final int? bytesTotal;
  final String? localPath;
  final String? errorMessage;
  final DateTime updatedAt;

  /// Hydrated from the manifest at the start of the streaming session.
  /// Default [DownloadKind.cache] when no manifest entry exists.
  ///
  /// Does NOT participate in equality — a flip cache↔download via
  /// `setEpisodeKind` does not retrigger emission on an active stream.
  final DownloadKind kind;

  const EpisodeDownload({
    required this.episodeId,
    required this.status,
    required this.bytesReceived,
    required this.updatedAt,
    this.bytesTotal,
    this.localPath,
    this.errorMessage,
    this.kind = DownloadKind.cache,
  });

  /// `true` when [status] allows the player to open [localPath].
  bool get isPlayable =>
      status == DownloadStatus.readyToPlay ||
      status == DownloadStatus.complete;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EpisodeDownload &&
          other.episodeId == episodeId &&
          other.status == status &&
          other.bytesReceived == bytesReceived &&
          other.updatedAt == updatedAt);

  @override
  int get hashCode =>
      Object.hash(episodeId, status, bytesReceived, updatedAt);

  @override
  String toString() =>
      'EpisodeDownload(episodeId: $episodeId, status: $status, '
      'bytesReceived: $bytesReceived, bytesTotal: $bytesTotal)';
}
