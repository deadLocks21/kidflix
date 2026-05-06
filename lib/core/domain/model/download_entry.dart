import 'package:kidflix/core/domain/model/download_kind.dart';

/// Discriminator between movie and episode entries in the inventory.
enum DownloadMediaKind { movie, episode }

/// Parent-facing inventory record — the projection used by the manager
/// page. Aggregates one downloaded item with its applicative metadata
/// (manifest) and its display data (resolved against the catalog or
/// series repository).
///
/// Built by `ListDownloadsUseCase`. Not exposed by the low-level
/// `DownloadRepository` directly — the repository returns
/// `DownloadInventoryRecord` instances, which the use case decorates
/// with [displayTitle], [displayPosterUrl], and [parentSeriesTitle].
///
/// Equatable by `(mediaKind, mediaId)`.
class DownloadEntry {
  final String mediaId;
  final DownloadMediaKind mediaKind;

  final DownloadKind kind;
  final int bytesOnDisk;
  final DateTime? completedAt;
  final DateTime? lastPlayedAt;
  final String? triggeredByProfileId;

  /// Resolved title, or `"Vidéo inconnue"` when the catalog/series
  /// lookup failed (item present on disk but not in the catalog).
  final String displayTitle;

  /// Resolved poster URL, or `null` when missing or unresolvable.
  final String? displayPosterUrl;

  /// For episodes: the parent series title, e.g. `"Pingu"`. Null for
  /// movies and for unresolvable episodes.
  final String? parentSeriesTitle;

  /// For episodes: the parent series id, used to dedupe several
  /// episodes of the same series down to a single series card on the
  /// home row. Null for movies and for unresolvable episodes.
  final String? parentSeriesId;

  const DownloadEntry({
    required this.mediaId,
    required this.mediaKind,
    required this.kind,
    required this.bytesOnDisk,
    required this.displayTitle,
    this.completedAt,
    this.lastPlayedAt,
    this.triggeredByProfileId,
    this.displayPosterUrl,
    this.parentSeriesTitle,
    this.parentSeriesId,
  });

  bool get isEpisode => mediaKind == DownloadMediaKind.episode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DownloadEntry &&
          other.mediaKind == mediaKind &&
          other.mediaId == mediaId);

  @override
  int get hashCode => Object.hash(mediaKind, mediaId);

  @override
  String toString() =>
      'DownloadEntry(${mediaKind.name}/$mediaId, '
      'kind: ${kind.name}, bytes: $bytesOnDisk, '
      'title: $displayTitle)';
}
