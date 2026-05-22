import 'package:flutter_test/flutter_test.dart';
import 'package:kidflix/core/domain/model/track_preferences.dart';
import 'package:kidflix/infrastructure/track_preferences/shared_prefs.track_preferences.repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('returns null for an unknown profile', () async {
    final repo = SharedPrefsTrackPreferencesRepository();
    expect(await repo.findForProfile('unknown'), isNull);
  });

  test(
    'round-trips audio + subtitle languages and the disabled flag',
    () async {
      final repo = SharedPrefsTrackPreferencesRepository();
      await repo.save(
        const TrackPreferences(
          profileId: 'p1',
          audioLanguage: 'fr',
          subtitleLanguage: 'en',
          subtitlesDisabled: true,
        ),
      );

      final loaded = await repo.findForProfile('p1');
      expect(loaded?.profileId, 'p1');
      expect(loaded?.audioLanguage, 'fr');
      expect(loaded?.subtitleLanguage, 'en');
      expect(loaded?.subtitlesDisabled, isTrue);
    },
  );

  test('save replaces the previous entry for the same profile', () async {
    final repo = SharedPrefsTrackPreferencesRepository();
    await repo.save(
      const TrackPreferences(profileId: 'p1', audioLanguage: 'fr'),
    );
    await repo.save(
      const TrackPreferences(profileId: 'p1', audioLanguage: 'en'),
    );

    final loaded = await repo.findForProfile('p1');
    expect(loaded?.audioLanguage, 'en');
    expect(loaded?.subtitleLanguage, isNull);
    expect(loaded?.subtitlesDisabled, isFalse);
  });

  test('isolates entries by profile id', () async {
    final repo = SharedPrefsTrackPreferencesRepository();
    await repo.save(
      const TrackPreferences(profileId: 'p1', audioLanguage: 'fr'),
    );
    await repo.save(
      const TrackPreferences(profileId: 'p2', audioLanguage: 'en'),
    );

    expect((await repo.findForProfile('p1'))?.audioLanguage, 'fr');
    expect((await repo.findForProfile('p2'))?.audioLanguage, 'en');
  });
}
