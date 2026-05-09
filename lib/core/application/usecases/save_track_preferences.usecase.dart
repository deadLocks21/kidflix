import 'package:kidflix/core/domain/model/track_preferences.dart';
import 'package:kidflix/core/domain/services/track_preferences.repository.dart';

/// Upserts the audio + subtitle language preferences for a profile.
class SaveTrackPreferencesUseCase {
  final TrackPreferencesRepository _repository;

  const SaveTrackPreferencesUseCase(this._repository);

  Future<void> execute(TrackPreferences preferences) {
    return _repository.save(preferences);
  }
}
