import 'package:kidflix/core/domain/model/track_preferences.dart';

/// Contract for persisting and retrieving a profile's audio + subtitle
/// language preferences.
///
/// Upsert semantics: [save] replaces any existing entry for the same
/// `profileId`. Returns `null` from [findForProfile] when the profile
/// has no recorded preference yet (first playback ever, or after a fresh
/// install).
///
/// Implementations live in `lib/infrastructure/track_preferences/`.
abstract interface class TrackPreferencesRepository {
  /// Returns the stored preferences for [profileId], or `null` when
  /// none exist. Never throws on missing data.
  Future<TrackPreferences?> findForProfile(String profileId);

  /// Upserts [preferences]. Any existing entry for the same `profileId`
  /// is replaced verbatim.
  Future<void> save(TrackPreferences preferences);
}
