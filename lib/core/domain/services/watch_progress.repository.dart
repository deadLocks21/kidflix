import 'package:kidflix/core/domain/model/watch_progress.dart';

/// Contract for persisting and retrieving a profile's playback progress
/// across both movies and episodes.
///
/// The two `findFor*` getters are typed by kind because call sites
/// always know statically what they need (the player layer holds either
/// a `Movie` or an `Episode`, never an arbitrary `PlayableMedia`).
/// `save` accepts the sealed [WatchProgress] and dispatches internally
/// to the right namespace ; `listForProfile` returns mixed entries.
///
/// Upsert semantics: [save] replaces any existing entry for the same
/// `(profileId, mediaId)` pair within its own kind. The repository
/// never merges or accumulates — the caller (the player) owns the
/// position value. Per the contract documented in `DISMISS_FEATURE.md`,
/// the server resets `dismissed = false` on every successful save ; the
/// in-memory implementation honours the same rule so dev mode matches
/// production.
///
/// The four `dismiss*` / `unDismiss*` methods toggle the Continue
/// Watching opt-out flag without touching the stored position. They
/// require an existing entry — calling them on an unknown pair surfaces
/// as a `DioException`/`404` on the HTTP impl and is silently treated
/// as a no-op by the in-memory impl (mirrors the idempotent semantics).
///
/// Implementations live in `lib/infrastructure/watch_progress/`.
abstract interface class WatchProgressRepository {
  /// Returns the stored movie progress for the given pair, or `null`
  /// when none exists. Never throws on missing data.
  Future<MovieProgress?> findForMovie({
    required String profileId,
    required String movieId,
  });

  /// Returns the stored episode progress for the given pair, or `null`
  /// when none exists. Never throws on missing data.
  Future<EpisodeProgress?> findForEpisode({
    required String profileId,
    required String episodeId,
  });

  /// Upserts [progress]. The implementation switches on the sealed
  /// [WatchProgress] variant and persists into the right namespace.
  /// Any existing entry for the same `(profileId, mediaId)` within the
  /// same kind is replaced verbatim. The `dismissed` flag is always
  /// reset to `false` by the server on successful save (cf. class
  /// docstring) — clients SHOULD NOT set `dismissed: true` on the
  /// passed progress.
  Future<void> save(WatchProgress progress);

  /// Returns every progress (movies AND episodes) recorded for
  /// [profileId] in an implementation-defined order. Empty list when
  /// none exists.
  Future<List<WatchProgress>> listForProfile(String profileId);

  /// Marks a movie progress as dismissed from the Continue Watching row.
  /// Idempotent: rejoue le `POST` est sans effet.
  Future<void> dismissMovie({
    required String profileId,
    required String movieId,
  });

  /// Clears the dismiss flag on a movie progress.
  /// Idempotent: rejoue le `DELETE` est sans effet.
  Future<void> unDismissMovie({
    required String profileId,
    required String movieId,
  });

  /// Marks an episode progress as dismissed from the Continue Watching
  /// row. Dismissing a single episode is sufficient to remove the
  /// parent series from the row (the row dedups by series, so only the
  /// most-recent episode entry is ever displayed).
  Future<void> dismissEpisode({
    required String profileId,
    required String episodeId,
  });

  /// Clears the dismiss flag on an episode progress. Idempotent.
  Future<void> unDismissEpisode({
    required String profileId,
    required String episodeId,
  });
}
