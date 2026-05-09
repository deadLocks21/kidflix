import 'package:kidflix/core/domain/services/track_preferences.repository.dart';
import 'package:kidflix/infrastructure/track_preferences/shared_prefs.track_preferences.repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'track_preferences.repository_provider.g.dart';

/// Audio + subtitle language preferences are stored locally on the
/// device — no backend involvement — so the provider always returns the
/// `SharedPreferences`-backed implementation. Tests override this
/// provider with `InMemoryTrackPreferencesRepository`.
@Riverpod(keepAlive: true)
TrackPreferencesRepository trackPreferencesRepository(Ref ref) {
  return SharedPrefsTrackPreferencesRepository();
}
