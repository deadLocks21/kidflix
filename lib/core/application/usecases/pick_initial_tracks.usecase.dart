import 'package:kidflix/core/domain/model/media_track.dart';
import 'package:kidflix/core/domain/model/track_preferences.dart';

/// Resolution chosen for the initial track selection of a fresh playback.
///
/// Each id, when non-null, refers to an entry in the engine's track list
/// — the caller passes it back to `setAudioTrack` / `setSubtitleTrack`.
/// `null` means « no preferred match found, leave the engine on its
/// default ». [disableSubtitles] is the explicit « off » signal: the
/// caller should call `setSubtitleTrack('no')` even though
/// [subtitleId] is null.
typedef InitialTracksSelection = ({
  String? audioId,
  String? subtitleId,
  bool disableSubtitles,
});

/// Picks the initial audio + subtitle tracks for a freshly opened media
/// based on the user's saved [TrackPreferences].
///
/// Match rule: exact equality on the lowercased `language` code, first
/// hit wins. Tracks without a `language` field are never matched (the
/// user can still pick them manually from the selector).
class PickInitialTracksUseCase {
  const PickInitialTracksUseCase();

  InitialTracksSelection execute({
    required List<MediaTrack> audio,
    required List<MediaTrack> subtitle,
    required TrackPreferences? preferences,
  }) {
    if (preferences == null) {
      return (audioId: null, subtitleId: null, disableSubtitles: false);
    }
    final audioId = _matchByLanguage(audio, preferences.audioLanguage);
    if (preferences.subtitlesDisabled) {
      return (audioId: audioId, subtitleId: null, disableSubtitles: true);
    }
    final subtitleId = _matchByLanguage(subtitle, preferences.subtitleLanguage);
    return (
      audioId: audioId,
      subtitleId: subtitleId,
      disableSubtitles: false,
    );
  }

  String? _matchByLanguage(List<MediaTrack> tracks, String? language) {
    if (language == null) return null;
    for (final t in tracks) {
      if (t.language != null && t.language == language) return t.id;
    }
    return null;
  }
}
