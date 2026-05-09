/// Persisted audio + subtitle language preferences for a profile.
///
/// `audioLanguage` / `subtitleLanguage` hold ISO codes (lowercased) — the
/// user's last picked track's language. `null` means « jamais choisi »
/// (no preference yet, leave the engine on `auto`).
///
/// `subtitlesDisabled` distinguishes « pas encore choisi » from
/// « explicitement désactivés » : when true, the player applies the
/// engine's `no` track even if a matching language exists in the file.
class TrackPreferences {
  final String profileId;
  final String? audioLanguage;
  final String? subtitleLanguage;
  final bool subtitlesDisabled;

  const TrackPreferences({
    required this.profileId,
    this.audioLanguage,
    this.subtitleLanguage,
    this.subtitlesDisabled = false,
  });

  TrackPreferences copyWith({
    String? audioLanguage,
    String? subtitleLanguage,
    bool? subtitlesDisabled,
    bool clearAudioLanguage = false,
    bool clearSubtitleLanguage = false,
  }) {
    return TrackPreferences(
      profileId: profileId,
      audioLanguage:
          clearAudioLanguage ? null : (audioLanguage ?? this.audioLanguage),
      subtitleLanguage: clearSubtitleLanguage
          ? null
          : (subtitleLanguage ?? this.subtitleLanguage),
      subtitlesDisabled: subtitlesDisabled ?? this.subtitlesDisabled,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TrackPreferences &&
          other.profileId == profileId &&
          other.audioLanguage == audioLanguage &&
          other.subtitleLanguage == subtitleLanguage &&
          other.subtitlesDisabled == subtitlesDisabled);

  @override
  int get hashCode => Object.hash(
        profileId,
        audioLanguage,
        subtitleLanguage,
        subtitlesDisabled,
      );

  @override
  String toString() =>
      'TrackPreferences(profileId: $profileId, audioLanguage: $audioLanguage, '
      'subtitleLanguage: $subtitleLanguage, subtitlesDisabled: $subtitlesDisabled)';
}
