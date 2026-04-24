import 'package:kidflix/core/domain/model/watch_progress.dart';

/// Contract for persisting and retrieving a profile's playback progress
/// for movies.
///
/// Upsert semantics: [save] replaces any existing entry for the same
/// `(profileId, movieId)` pair. The repository never merges or
/// accumulates progress — the caller (the `PlayerPage`) owns the
/// position value.
///
/// Implementations live in `lib/infrastructure/watch_progress/`.
abstract interface class WatchProgressRepository {
  /// Returns the stored progress for the given profile/movie pair, or
  /// `null` when none exists. Never throws on missing data.
  Future<WatchProgress?> findFor({
    required String profileId,
    required String movieId,
  });

  /// Upserts [progress]. Any existing entry for the same
  /// `(profileId, movieId)` is replaced verbatim.
  Future<void> save(WatchProgress progress);

  /// Returns every progress recorded for [profileId] in an
  /// implementation-defined order. Empty list when none exists.
  Future<List<WatchProgress>> listForProfile(String profileId);
}
