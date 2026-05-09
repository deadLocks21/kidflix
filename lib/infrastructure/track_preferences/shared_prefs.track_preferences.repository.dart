import 'dart:convert';

import 'package:kidflix/core/domain/model/track_preferences.dart';
import 'package:kidflix/core/domain/services/track_preferences.repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _trackPrefsKeyPrefix = 'track_prefs.';

/// `SharedPreferences`-backed [TrackPreferencesRepository].
///
/// One JSON-encoded entry per profile, stored under the key
/// `track_prefs.<profileId>`. Schema:
///
/// ```json
/// {"audioLanguage": "fr", "subtitleLanguage": null, "subtitlesDisabled": true}
/// ```
class SharedPrefsTrackPreferencesRepository
    implements TrackPreferencesRepository {
  final Future<SharedPreferences> Function() _resolvePrefs;

  SharedPrefsTrackPreferencesRepository({
    Future<SharedPreferences> Function()? resolvePrefs,
  }) : _resolvePrefs = resolvePrefs ?? SharedPreferences.getInstance;

  String _key(String profileId) => '$_trackPrefsKeyPrefix$profileId';

  @override
  Future<TrackPreferences?> findForProfile(String profileId) async {
    final prefs = await _resolvePrefs();
    final raw = prefs.getString(_key(profileId));
    if (raw == null) return null;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return TrackPreferences(
        profileId: profileId,
        audioLanguage: json['audioLanguage'] as String?,
        subtitleLanguage: json['subtitleLanguage'] as String?,
        subtitlesDisabled: (json['subtitlesDisabled'] as bool?) ?? false,
      );
    } catch (_) {
      // Stored payload is corrupt — treat as absent. Next save will heal.
      return null;
    }
  }

  @override
  Future<void> save(TrackPreferences preferences) async {
    final prefs = await _resolvePrefs();
    final payload = jsonEncode({
      'audioLanguage': preferences.audioLanguage,
      'subtitleLanguage': preferences.subtitleLanguage,
      'subtitlesDisabled': preferences.subtitlesDisabled,
    });
    await prefs.setString(_key(preferences.profileId), payload);
  }
}
