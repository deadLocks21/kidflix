import 'package:kidflix/core/domain/model/download_kind.dart';

/// Persisted applicative metadata for a single download (movie or
/// episode). Lives inside the JSON sidecar `manifest.json` keyed by
/// composite identifier (`movies/<id>` or `episodes/<id>`).
///
/// Forward-compatible parser: unknown keys in the JSON are ignored,
/// missing keys fall back to safe defaults (`kind = cache`, others null).
///
/// **Why cached display metadata** (`cachedTitle` / `cachedPosterUrl` /
/// `cachedParentSeriesTitle`): per `API.md` § Catalogue, `/catalog`
/// returns ONLY items whose age category EXACTLY matches the active
/// profile's. The downloads manager — opened from the parent profile
/// — therefore cannot resolve titles for items targeting a different
/// age category (e.g. baby content downloaded by a parent profile).
/// Persisting the title + poster at the moment the user triggers the
/// action (when the caller already holds the catalog object) bypasses
/// this filter entirely. The manifest becomes the source of truth for
/// the manager UI, with the catalog as a best-effort fallback.
class DownloadManifestEntry {
  final DownloadKind kind;
  final DateTime? completedAt;
  final DateTime? lastPlayedAt;
  final String? triggeredByProfileId;

  /// Title captured at action time (player open or [Télécharger]).
  /// Survives catalog filter changes and item removals.
  final String? cachedTitle;

  /// Poster / thumbnail URL captured at action time.
  final String? cachedPosterUrl;

  /// For episodes only: the parent series title, captured alongside
  /// the episode title.
  final String? cachedParentSeriesTitle;

  const DownloadManifestEntry({
    required this.kind,
    this.completedAt,
    this.lastPlayedAt,
    this.triggeredByProfileId,
    this.cachedTitle,
    this.cachedPosterUrl,
    this.cachedParentSeriesTitle,
  });

  /// Default-valued entry — used as a placeholder when an item is on
  /// disk but has no manifest record (rétro-classified).
  factory DownloadManifestEntry.cacheDefault({DateTime? lastPlayedAt}) {
    return DownloadManifestEntry(
      kind: DownloadKind.cache,
      lastPlayedAt: lastPlayedAt,
    );
  }

  DownloadManifestEntry copyWith({
    DownloadKind? kind,
    DateTime? completedAt,
    DateTime? lastPlayedAt,
    String? triggeredByProfileId,
    String? cachedTitle,
    String? cachedPosterUrl,
    String? cachedParentSeriesTitle,
    bool clearCompletedAt = false,
    bool clearLastPlayedAt = false,
    bool clearTriggeredByProfileId = false,
  }) {
    return DownloadManifestEntry(
      kind: kind ?? this.kind,
      completedAt: clearCompletedAt ? null : (completedAt ?? this.completedAt),
      lastPlayedAt:
          clearLastPlayedAt ? null : (lastPlayedAt ?? this.lastPlayedAt),
      triggeredByProfileId: clearTriggeredByProfileId
          ? null
          : (triggeredByProfileId ?? this.triggeredByProfileId),
      cachedTitle: cachedTitle ?? this.cachedTitle,
      cachedPosterUrl: cachedPosterUrl ?? this.cachedPosterUrl,
      cachedParentSeriesTitle:
          cachedParentSeriesTitle ?? this.cachedParentSeriesTitle,
    );
  }

  Map<String, dynamic> toJson() => {
        'kind': kind.jsonValue,
        if (completedAt != null) 'completedAt': completedAt!.toIso8601String(),
        if (lastPlayedAt != null)
          'lastPlayedAt': lastPlayedAt!.toIso8601String(),
        if (triggeredByProfileId != null)
          'triggeredByProfileId': triggeredByProfileId,
        if (cachedTitle != null) 'cachedTitle': cachedTitle,
        if (cachedPosterUrl != null) 'cachedPosterUrl': cachedPosterUrl,
        if (cachedParentSeriesTitle != null)
          'cachedParentSeriesTitle': cachedParentSeriesTitle,
      };

  /// Tolerant parser: any malformed/missing field falls back to its safe
  /// default. Unknown keys in [json] are silently ignored.
  static DownloadManifestEntry fromJson(Map<String, dynamic> json) {
    return DownloadManifestEntry(
      kind: DownloadKind.fromJson(json['kind'] as String?),
      completedAt: _parseDate(json['completedAt']),
      lastPlayedAt: _parseDate(json['lastPlayedAt']),
      triggeredByProfileId: json['triggeredByProfileId'] as String?,
      cachedTitle: json['cachedTitle'] as String?,
      cachedPosterUrl: json['cachedPosterUrl'] as String?,
      cachedParentSeriesTitle: json['cachedParentSeriesTitle'] as String?,
    );
  }

  static DateTime? _parseDate(Object? raw) {
    if (raw is! String) return null;
    return DateTime.tryParse(raw)?.toUtc();
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DownloadManifestEntry &&
          other.kind == kind &&
          other.completedAt == completedAt &&
          other.lastPlayedAt == lastPlayedAt &&
          other.triggeredByProfileId == triggeredByProfileId &&
          other.cachedTitle == cachedTitle &&
          other.cachedPosterUrl == cachedPosterUrl &&
          other.cachedParentSeriesTitle == cachedParentSeriesTitle);

  @override
  int get hashCode => Object.hash(
        kind,
        completedAt,
        lastPlayedAt,
        triggeredByProfileId,
        cachedTitle,
        cachedPosterUrl,
        cachedParentSeriesTitle,
      );

  @override
  String toString() =>
      'DownloadManifestEntry(kind: ${kind.name}, '
      'completedAt: $completedAt, lastPlayedAt: $lastPlayedAt, '
      'triggeredByProfileId: $triggeredByProfileId, '
      'cachedTitle: $cachedTitle)';
}
