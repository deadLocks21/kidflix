import 'package:kidflix/core/domain/model/track_preferences.dart';
import 'package:kidflix/core/domain/services/track_preferences.repository.dart';

/// RAM-only [TrackPreferencesRepository] used by widget tests and the
/// web build. Entries are lost at app restart.
class InMemoryTrackPreferencesRepository implements TrackPreferencesRepository {
  final Map<String, TrackPreferences> _byProfileId = {};

  @override
  Future<TrackPreferences?> findForProfile(String profileId) async {
    return _byProfileId[profileId];
  }

  @override
  Future<void> save(TrackPreferences preferences) async {
    _byProfileId[preferences.profileId] = preferences;
  }
}
