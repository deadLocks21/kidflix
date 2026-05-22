/// A single entry in the family's Watcharr-backed wishlist, surfaced to
/// the parent profile from `GET /wishlist` on kidflix-api.
///
/// One [WishlistEntry] aggregates two facets in one record:
///
/// 1. The wire-side identity emitted by Watcharr — `watcharrId`,
///    `tmdbId`, `kind`, `title`, `year`, `posterUrl`, `status`, `rating`.
/// 2. The catalog-side crossing computed server-side —
///    `availableInCatalog` + `catalogId` — telling whether the same
///    TMDB item already ships in the local kdrive catalog and, when it
///    does, the Kidflix `id` to push toward the player.
///
/// Identity is `(watcharrId)` only — `tmdbId` is sufficient for human
/// disambiguation but isn't guaranteed unique across Watcharr accounts.
/// `status` and `rating` are mutable state.
///
/// `kind` discriminates movie vs series at the Watcharr layer. When
/// `availableInCatalog` is `true`, `catalogId` resolves to a row in
/// the corresponding domain table (movies for `kind == movie`, series
/// for `kind == series`). When `availableInCatalog` is `false`,
/// `catalogId` is `null` and the entry is rendered as a "to acquire"
/// item in the UI (no playback affordance).
///
/// Episodes (`tv_episode` in Watcharr) are filtered out by the
/// backend — they are not exposed as wishlist entries.
class WishlistEntry {
  /// Internal id Watcharr assigns to the watchlist entry. Required to
  /// target subsequent mutations (`DELETE /wishlist/{id}`,
  /// `PUT /wishlist/{id}/status`).
  final int watcharrId;

  /// TMDB id of the underlying movie / series. Drives the crossing
  /// with the local catalog server-side.
  final int tmdbId;

  /// Whether this entry refers to a movie or to a TV series.
  final WishlistItemKind kind;

  final String title;
  final int? year;
  final String? posterUrl;

  /// Watcharr-side status. The wishlist UI typically renders entries
  /// in `planned`, `watching` and `hold`. `finished` and `dropped`
  /// items remain returned by the API so the parent can re-surface or
  /// re-classify them, but they are not the primary use case.
  final WatchedStatus status;

  /// 0-10. `0` means "not yet rated".
  final int rating;

  /// Crossing flag: `true` when the same TMDB id has a non-deleted
  /// row in the local `movies` (or `series`) table at the time the
  /// response was computed.
  final bool availableInCatalog;

  /// When [availableInCatalog] is `true`, the Kidflix `id` of the
  /// resolved catalog row (movie id or series id depending on
  /// [kind]). `null` otherwise.
  final String? catalogId;

  const WishlistEntry({
    required this.watcharrId,
    required this.tmdbId,
    required this.kind,
    required this.title,
    required this.status,
    required this.rating,
    required this.availableInCatalog,
    this.year,
    this.posterUrl,
    this.catalogId,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WishlistEntry && other.watcharrId == watcharrId);

  @override
  int get hashCode => watcharrId.hashCode;

  @override
  String toString() =>
      'WishlistEntry(watcharrId: $watcharrId, tmdbId: $tmdbId, '
      'kind: $kind, title: $title, status: $status, '
      'availableInCatalog: $availableInCatalog, catalogId: $catalogId)';

  WishlistEntry copyWith({
    WatchedStatus? status,
    int? rating,
    bool? availableInCatalog,
    String? catalogId,
  }) {
    return WishlistEntry(
      watcharrId: watcharrId,
      tmdbId: tmdbId,
      kind: kind,
      title: title,
      year: year,
      posterUrl: posterUrl,
      status: status ?? this.status,
      rating: rating ?? this.rating,
      availableInCatalog: availableInCatalog ?? this.availableInCatalog,
      catalogId: catalogId ?? this.catalogId,
    );
  }
}

/// What an entry refers to. Mirrors Watcharr's `content.type` after
/// filtering out `tv_episode` and `game` upstream of the API surface.
enum WishlistItemKind { movie, series }

/// Watcharr `Watched.status` enum. The wire format is uppercase
/// (`PLANNED`, `WATCHING`, …) — translation lives in the DTO layer.
enum WatchedStatus {
  /// "À voir" — the wishlist proper.
  planned,

  /// Currently being watched (mostly used for series in Watcharr).
  watching,

  /// Finished. Stays in the catalog response so the parent can re-add
  /// it manually if needed.
  finished,

  /// Paused / on hold.
  hold,

  /// Abandoned. Surfaced by the API but typically filtered out by the
  /// UI.
  dropped,
}
