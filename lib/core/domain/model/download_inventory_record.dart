import 'package:kidflix/core/domain/model/download_kind.dart';

/// Raw inventory record returned by `DownloadRepository.listAll()`.
///
/// Filesystem-backed, manifest-aware, but *not* decorated with catalog
/// metadata — that decoration is the responsibility of
/// `ListDownloadsUseCase`, which produces a `DownloadEntry` from this
/// record.
///
/// Equatable by `(isEpisode, mediaId)`.
class DownloadInventoryRecord {
  final String mediaId;
  final bool isEpisode;
  final int bytesOnDisk;
  final DownloadKind kind;
  final DateTime? completedAt;
  final DateTime? lastPlayedAt;
  final String? triggeredByProfileId;

  /// Display title captured at action time, surviving catalog filter
  /// limitations (cf. `DownloadManifestEntry.cachedTitle`). Null when
  /// the manifest has no entry or no captured title for this item.
  final String? cachedTitle;

  /// Captured poster / thumbnail URL. Null when unavailable.
  final String? cachedPosterUrl;

  /// For episodes only: captured parent series title. Null otherwise.
  final String? cachedParentSeriesTitle;

  const DownloadInventoryRecord({
    required this.mediaId,
    required this.isEpisode,
    required this.bytesOnDisk,
    required this.kind,
    this.completedAt,
    this.lastPlayedAt,
    this.triggeredByProfileId,
    this.cachedTitle,
    this.cachedPosterUrl,
    this.cachedParentSeriesTitle,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DownloadInventoryRecord &&
          other.isEpisode == isEpisode &&
          other.mediaId == mediaId);

  @override
  int get hashCode => Object.hash(isEpisode, mediaId);

  @override
  String toString() =>
      'DownloadInventoryRecord('
      '${isEpisode ? 'episode' : 'movie'}/$mediaId, '
      'kind: ${kind.name}, bytes: $bytesOnDisk)';
}
