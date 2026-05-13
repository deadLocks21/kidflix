import 'package:kidflix/core/domain/model/cached_cast_member.dart';
import 'package:kidflix/core/domain/model/download_kind.dart';

export 'package:kidflix/core/domain/model/cached_cast_member.dart';

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
///
/// **Why full metadata snapshot** (`cachedYear`, `cachedDurationSeconds`,
/// `cachedAgeCategory`, `cachedSynopsis`, `cachedTagline`,
/// `cachedOriginalTitle`, `cachedBackdropUrl`, `cachedLogoUrl`,
/// `cachedGenres`, `cachedDirector`, `cachedTopCast`): when the device is
/// offline, the homepage and detail modal must render using only what is
/// on disk. The catalog and detail endpoints are both unreachable in that
/// state, so the manifest doubles as a local mini-catalog. The snapshot
/// captures everything required to reconstruct a `Movie` / `Series` and
/// project it to `MovieDetailDto` / `SeriesDto` without any network call.
/// All fields are optional and tolerant on parse to preserve backward
/// compatibility with manifests written before this addition.
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

  /// Original-language title (e.g. for foreign films).
  final String? cachedOriginalTitle;

  /// Release year.
  final int? cachedYear;

  /// Runtime in seconds — stored as int (Duration is non-JSON-native).
  final int? cachedDurationSeconds;

  /// Age category as the enum's `.name` (`"bebe"`, `"enfant"`, …).
  /// Drives offline row grouping and the profile age filter.
  final String? cachedAgeCategory;

  /// Plot synopsis as displayed in the detail modal.
  final String? cachedSynopsis;

  /// Optional tagline / catch phrase.
  final String? cachedTagline;

  /// Backdrop URL (large hero image in the detail modal).
  final String? cachedBackdropUrl;

  /// Logo URL (title artwork overlay).
  final String? cachedLogoUrl;

  /// Genres for row grouping and chips. Empty when none captured.
  final List<String> cachedGenres;

  /// Director(s). Empty when none captured.
  final List<String> cachedDirector;

  /// Top cast (5 max — same cap as `MovieDetailDto.topCast`).
  /// Empty when none captured.
  final List<CachedCastMember> cachedTopCast;

  /// For episode entries: the parent series id, used by the offline
  /// catalog reconstruction to group episodes under their series card.
  final String? cachedSeriesId;

  /// For episode entries: the season number (TMM `0` is the Specials
  /// container). Captured at action time so the offline series detail
  /// modal can rebuild the seasons tree.
  final int? cachedSeasonNumber;

  /// For episode entries: the episode number within its season.
  final int? cachedEpisodeNumber;

  /// For series entries: total seasons reported by the backend at
  /// snapshot time. Mirrors `Series.seasonsCount`.
  final int? cachedSeasonsCount;

  /// For series entries: total episodes reported by the backend at
  /// snapshot time. Mirrors `Series.episodesCount`.
  final int? cachedEpisodesCount;

  const DownloadManifestEntry({
    required this.kind,
    this.completedAt,
    this.lastPlayedAt,
    this.triggeredByProfileId,
    this.cachedTitle,
    this.cachedPosterUrl,
    this.cachedParentSeriesTitle,
    this.cachedOriginalTitle,
    this.cachedYear,
    this.cachedDurationSeconds,
    this.cachedAgeCategory,
    this.cachedSynopsis,
    this.cachedTagline,
    this.cachedBackdropUrl,
    this.cachedLogoUrl,
    this.cachedGenres = const [],
    this.cachedDirector = const [],
    this.cachedTopCast = const [],
    this.cachedSeriesId,
    this.cachedSeasonNumber,
    this.cachedEpisodeNumber,
    this.cachedSeasonsCount,
    this.cachedEpisodesCount,
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
    String? cachedOriginalTitle,
    int? cachedYear,
    int? cachedDurationSeconds,
    String? cachedAgeCategory,
    String? cachedSynopsis,
    String? cachedTagline,
    String? cachedBackdropUrl,
    String? cachedLogoUrl,
    List<String>? cachedGenres,
    List<String>? cachedDirector,
    List<CachedCastMember>? cachedTopCast,
    String? cachedSeriesId,
    int? cachedSeasonNumber,
    int? cachedEpisodeNumber,
    int? cachedSeasonsCount,
    int? cachedEpisodesCount,
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
      cachedOriginalTitle: cachedOriginalTitle ?? this.cachedOriginalTitle,
      cachedYear: cachedYear ?? this.cachedYear,
      cachedDurationSeconds:
          cachedDurationSeconds ?? this.cachedDurationSeconds,
      cachedAgeCategory: cachedAgeCategory ?? this.cachedAgeCategory,
      cachedSynopsis: cachedSynopsis ?? this.cachedSynopsis,
      cachedTagline: cachedTagline ?? this.cachedTagline,
      cachedBackdropUrl: cachedBackdropUrl ?? this.cachedBackdropUrl,
      cachedLogoUrl: cachedLogoUrl ?? this.cachedLogoUrl,
      cachedGenres: cachedGenres ?? this.cachedGenres,
      cachedDirector: cachedDirector ?? this.cachedDirector,
      cachedTopCast: cachedTopCast ?? this.cachedTopCast,
      cachedSeriesId: cachedSeriesId ?? this.cachedSeriesId,
      cachedSeasonNumber: cachedSeasonNumber ?? this.cachedSeasonNumber,
      cachedEpisodeNumber: cachedEpisodeNumber ?? this.cachedEpisodeNumber,
      cachedSeasonsCount: cachedSeasonsCount ?? this.cachedSeasonsCount,
      cachedEpisodesCount: cachedEpisodesCount ?? this.cachedEpisodesCount,
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
        if (cachedOriginalTitle != null)
          'cachedOriginalTitle': cachedOriginalTitle,
        if (cachedYear != null) 'cachedYear': cachedYear,
        if (cachedDurationSeconds != null)
          'cachedDurationSeconds': cachedDurationSeconds,
        if (cachedAgeCategory != null) 'cachedAgeCategory': cachedAgeCategory,
        if (cachedSynopsis != null) 'cachedSynopsis': cachedSynopsis,
        if (cachedTagline != null) 'cachedTagline': cachedTagline,
        if (cachedBackdropUrl != null) 'cachedBackdropUrl': cachedBackdropUrl,
        if (cachedLogoUrl != null) 'cachedLogoUrl': cachedLogoUrl,
        if (cachedGenres.isNotEmpty) 'cachedGenres': cachedGenres,
        if (cachedDirector.isNotEmpty) 'cachedDirector': cachedDirector,
        if (cachedTopCast.isNotEmpty)
          'cachedTopCast': cachedTopCast.map((c) => c.toJson()).toList(),
        if (cachedSeriesId != null) 'cachedSeriesId': cachedSeriesId,
        if (cachedSeasonNumber != null)
          'cachedSeasonNumber': cachedSeasonNumber,
        if (cachedEpisodeNumber != null)
          'cachedEpisodeNumber': cachedEpisodeNumber,
        if (cachedSeasonsCount != null)
          'cachedSeasonsCount': cachedSeasonsCount,
        if (cachedEpisodesCount != null)
          'cachedEpisodesCount': cachedEpisodesCount,
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
      cachedOriginalTitle: json['cachedOriginalTitle'] as String?,
      cachedYear: _parseInt(json['cachedYear']),
      cachedDurationSeconds: _parseInt(json['cachedDurationSeconds']),
      cachedAgeCategory: json['cachedAgeCategory'] as String?,
      cachedSynopsis: json['cachedSynopsis'] as String?,
      cachedTagline: json['cachedTagline'] as String?,
      cachedBackdropUrl: json['cachedBackdropUrl'] as String?,
      cachedLogoUrl: json['cachedLogoUrl'] as String?,
      cachedGenres: _parseStringList(json['cachedGenres']),
      cachedDirector: _parseStringList(json['cachedDirector']),
      cachedTopCast: _parseCastList(json['cachedTopCast']),
      cachedSeriesId: json['cachedSeriesId'] as String?,
      cachedSeasonNumber: _parseInt(json['cachedSeasonNumber']),
      cachedEpisodeNumber: _parseInt(json['cachedEpisodeNumber']),
      cachedSeasonsCount: _parseInt(json['cachedSeasonsCount']),
      cachedEpisodesCount: _parseInt(json['cachedEpisodesCount']),
    );
  }

  static DateTime? _parseDate(Object? raw) {
    if (raw is! String) return null;
    return DateTime.tryParse(raw)?.toUtc();
  }

  static int? _parseInt(Object? raw) {
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    if (raw is String) return int.tryParse(raw);
    return null;
  }

  static List<String> _parseStringList(Object? raw) {
    if (raw is! List) return const [];
    return raw.whereType<String>().toList(growable: false);
  }

  static List<CachedCastMember> _parseCastList(Object? raw) {
    if (raw is! List) return const [];
    final out = <CachedCastMember>[];
    for (final item in raw) {
      if (item is Map) {
        final parsed = CachedCastMember.fromJson(item.cast<String, dynamic>());
        if (parsed != null) out.add(parsed);
      }
    }
    return List.unmodifiable(out);
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
          other.cachedParentSeriesTitle == cachedParentSeriesTitle &&
          other.cachedOriginalTitle == cachedOriginalTitle &&
          other.cachedYear == cachedYear &&
          other.cachedDurationSeconds == cachedDurationSeconds &&
          other.cachedAgeCategory == cachedAgeCategory &&
          other.cachedSynopsis == cachedSynopsis &&
          other.cachedTagline == cachedTagline &&
          other.cachedBackdropUrl == cachedBackdropUrl &&
          other.cachedLogoUrl == cachedLogoUrl &&
          _listEq(other.cachedGenres, cachedGenres) &&
          _listEq(other.cachedDirector, cachedDirector) &&
          _listEq(other.cachedTopCast, cachedTopCast) &&
          other.cachedSeriesId == cachedSeriesId &&
          other.cachedSeasonNumber == cachedSeasonNumber &&
          other.cachedEpisodeNumber == cachedEpisodeNumber &&
          other.cachedSeasonsCount == cachedSeasonsCount &&
          other.cachedEpisodesCount == cachedEpisodesCount);

  @override
  int get hashCode => Object.hash(
        kind,
        completedAt,
        lastPlayedAt,
        triggeredByProfileId,
        cachedTitle,
        cachedYear,
        cachedDurationSeconds,
        cachedAgeCategory,
        cachedSynopsis,
        Object.hashAll(cachedGenres),
        Object.hashAll(cachedDirector),
        Object.hashAll(cachedTopCast),
      );

  @override
  String toString() =>
      'DownloadManifestEntry(kind: ${kind.name}, '
      'completedAt: $completedAt, lastPlayedAt: $lastPlayedAt, '
      'triggeredByProfileId: $triggeredByProfileId, '
      'cachedTitle: $cachedTitle)';
}

bool _listEq<T>(List<T> a, List<T> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

