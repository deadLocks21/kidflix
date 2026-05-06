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
/// position value.
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
  /// same kind is replaced verbatim.
  Future<void> save(WatchProgress progress);

  /// Returns every progress (movies AND episodes) recorded for
  /// [profileId] in an implementation-defined order. Empty list when
  /// none exists.
  Future<List<WatchProgress>> listForProfile(String profileId);
}
