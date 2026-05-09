import 'package:kidflix/core/domain/model/track_preferences.dart';
import 'package:kidflix/core/domain/services/track_preferences.repository.dart';

/// Returns the persisted audio + subtitle language preferences for
/// [profileId], or `null` when none exist.
class LoadTrackPreferencesUseCase {
  final TrackPreferencesRepository _repository;

  const LoadTrackPreferencesUseCase(this._repository);

  Future<TrackPreferences?> execute(String profileId) {
    return _repository.findForProfile(profileId);
  }
}
