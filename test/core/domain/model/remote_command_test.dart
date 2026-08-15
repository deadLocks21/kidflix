import 'package:flutter_test/flutter_test.dart';
import 'package:kidflix/core/domain/model/remote_command.dart';

void main() {
  group('RemoteCommand round-trip', () {
    final commands = <RemoteCommand>[
      const RemotePlayCommand(),
      const RemotePauseCommand(),
      const RemoteTogglePlayCommand(),
      const RemoteStopCommand(),
      const RemoteNextEpisodeCommand(),
      const RemotePreviousEpisodeCommand(),
      const RemoteSeekCommand(Duration(minutes: 42, seconds: 7)),
      const RemoteSeekRelativeCommand(Duration(seconds: -10)),
      const RemoteSetAudioTrackCommand('3'),
      const RemoteSetSubtitleTrackCommand('no'),
      const RemoteSetVolumeCommand(65.5),
      const RemoteRetryDownloadCommand(),
      const RemoteSelectProfileCommand('profile-4'),
      const RemoteSubmitProfilePinCommand('1234'),
      const RemoteCancelProfilePinCommand(),
      const RemoteSetTextCommand('dino'),
      const RemoteDismissTextInputCommand(),
      const RemoteNavigateCommand(RemoteNavigationDirection.left),
      const RemotePlayMediaCommand(mediaId: 'movie-1'),
      const RemotePlayMediaCommand(
        mediaId: 'ep-9',
        isEpisode: true,
        seriesId: 'series-2',
        shuffle: true,
      ),
    ];

    for (final command in commands) {
      test('${command.type} survives encode → decode', () {
        final decoded = RemoteCommand.fromJson(command.toJson());

        expect(decoded.runtimeType, equals(command.runtimeType));
        expect(decoded!.toJson(), equals(command.toJson()));
      });
    }
  });

  test('seek carries its position in milliseconds', () {
    const command = RemoteSeekCommand(Duration(minutes: 1, seconds: 30));

    expect(command.toJson(), equals({'type': 'seek', 'positionMs': 90000}));
  });

  test('a negative relative seek stays negative', () {
    final decoded =
        RemoteCommand.fromJson(
              const RemoteSeekRelativeCommand(Duration(seconds: -10)).toJson(),
            )!
            as RemoteSeekRelativeCommand;

    expect(decoded.delta, equals(const Duration(seconds: -10)));
  });

  test('playMedia omits a null seriesId rather than writing null', () {
    const command = RemotePlayMediaCommand(mediaId: 'm1');

    expect(command.toJson().containsKey('seriesId'), isFalse);
  });

  group('tolerating unknown or malformed input', () {
    test('an unknown verb decodes to null', () {
      // A remote on a newer build may send verbs this host never heard
      // of; dropping them beats crashing the link.
      expect(RemoteCommand.fromJson({'type': 'teleport'}), isNull);
    });

    test('a missing type decodes to null', () {
      expect(RemoteCommand.fromJson({'positionMs': 12}), isNull);
    });

    test('a known verb missing its payload decodes to null', () {
      expect(RemoteCommand.fromJson({'type': 'seek'}), isNull);
      expect(RemoteCommand.fromJson({'type': 'setAudioTrack'}), isNull);
      expect(RemoteCommand.fromJson({'type': 'playMedia'}), isNull);
      expect(RemoteCommand.fromJson({'type': 'selectProfile'}), isNull);
      expect(RemoteCommand.fromJson({'type': 'submitProfilePin'}), isNull);
    });

    test('a PIN made only of digits survives its leading zeros', () {
      // Decoded as a String, never a number — `0042` must not become 42.
      final decoded =
          RemoteCommand.fromJson(
                const RemoteSubmitProfilePinCommand('0042').toJson(),
              )!
              as RemoteSubmitProfilePinCommand;

      expect(decoded.pin, equals('0042'));
    });

    test('a numeric PIN payload is refused rather than coerced', () {
      expect(
        RemoteCommand.fromJson({'type': 'submitProfilePin', 'pin': 1234}),
        isNull,
      );
    });

    test('a wrongly-typed payload decodes to null', () {
      expect(
        RemoteCommand.fromJson({'type': 'seek', 'positionMs': 'soon'}),
        isNull,
      );
    });

    test('typed text without a payload decodes to null', () {
      expect(RemoteCommand.fromJson({'type': 'setText'}), isNull);
    });

    test('empty text is a value, not a missing field', () {
      // Clearing the field is a real instruction — the host must empty
      // it, not ignore the frame.
      final decoded =
          RemoteCommand.fromJson({'type': 'setText', 'text': ''})!
              as RemoteSetTextCommand;

      expect(decoded.text, isEmpty);
    });

    test('every navigation direction survives the wire', () {
      for (final direction in RemoteNavigationDirection.values) {
        final decoded =
            RemoteCommand.fromJson(RemoteNavigateCommand(direction).toJson())!
                as RemoteNavigateCommand;

        expect(decoded.direction, equals(direction));
      }
    });

    test('an unknown navigation direction decodes to null', () {
      expect(
        RemoteCommand.fromJson({'type': 'navigate', 'direction': 'sideways'}),
        isNull,
      );
      expect(RemoteCommand.fromJson({'type': 'navigate'}), isNull);
    });

    test('an integer volume is accepted and widened to double', () {
      // JSON gives back an int for `65`, not a double.
      final decoded =
          RemoteCommand.fromJson({'type': 'setVolume', 'volume': 65})!
              as RemoteSetVolumeCommand;

      expect(decoded.volume, equals(65.0));
    });
  });
}
