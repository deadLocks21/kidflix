import 'package:flutter_test/flutter_test.dart';
import 'package:kidflix/core/application/usecases/pick_initial_tracks.usecase.dart';
import 'package:kidflix/core/domain/model/media_track.dart';
import 'package:kidflix/core/domain/model/track_preferences.dart';

void main() {
  group('PickInitialTracksUseCase', () {
    const usecase = PickInitialTracksUseCase();

    final frenchAudio = const MediaTrack(
      id: '1',
      kind: MediaTrackKind.audio,
      language: 'fr',
    );
    final englishAudio = const MediaTrack(
      id: '2',
      kind: MediaTrackKind.audio,
      language: 'en',
    );
    final frenchSubtitle = const MediaTrack(
      id: '3',
      kind: MediaTrackKind.subtitle,
      language: 'fr',
    );

    test('returns nulls when no preferences are stored', () {
      final result = usecase.execute(
        audio: [frenchAudio, englishAudio],
        subtitle: [frenchSubtitle],
        preferences: null,
      );
      expect(result.audioId, isNull);
      expect(result.subtitleId, isNull);
      expect(result.disableSubtitles, isFalse);
    });

    test('matches audio + subtitle by language', () {
      final result = usecase.execute(
        audio: [frenchAudio, englishAudio],
        subtitle: [frenchSubtitle],
        preferences: const TrackPreferences(
          profileId: 'p',
          audioLanguage: 'en',
          subtitleLanguage: 'fr',
        ),
      );
      expect(result.audioId, '2');
      expect(result.subtitleId, '3');
      expect(result.disableSubtitles, isFalse);
    });

    test('returns null id for languages absent from the file', () {
      final result = usecase.execute(
        audio: [frenchAudio],
        subtitle: const [],
        preferences: const TrackPreferences(
          profileId: 'p',
          audioLanguage: 'de',
          subtitleLanguage: 'de',
        ),
      );
      expect(result.audioId, isNull);
      expect(result.subtitleId, isNull);
    });

    test('honours subtitlesDisabled even when a matching language exists', () {
      final result = usecase.execute(
        audio: [frenchAudio],
        subtitle: [frenchSubtitle],
        preferences: const TrackPreferences(
          profileId: 'p',
          audioLanguage: 'fr',
          subtitleLanguage: 'fr',
          subtitlesDisabled: true,
        ),
      );
      expect(result.audioId, '1');
      expect(result.subtitleId, isNull);
      expect(result.disableSubtitles, isTrue);
    });
  });
}
