import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kidflix/core/application/remote/remote_protocol.dart';
import 'package:kidflix/core/domain/model/remote_command.dart';
import 'package:kidflix/core/domain/model/remote_playback_state.dart';

void main() {
  test('a command frame decodes back to the same command', () {
    final frame = RemoteProtocol.encodeCommand(
      const RemoteSetSubtitleTrackCommand('4'),
    );

    final message = RemoteProtocol.decode(frame);

    expect(message, isA<RemoteCommandMessage>());
    final command =
        (message as RemoteCommandMessage).command
            as RemoteSetSubtitleTrackCommand;
    expect(command.trackId, equals('4'));
  });

  test('a state frame decodes back to an equivalent state', () {
    const state = RemotePlaybackState(
      status: RemotePlaybackStatus.playing,
      mediaId: 'movie-3',
      mediaKind: 'movie',
      title: 'Vaiana',
      position: Duration(minutes: 12),
      duration: Duration(hours: 1, minutes: 47),
      volume: 80,
      audioTracks: [
        RemoteTrackOption(id: '1', label: 'Français', language: 'fre'),
      ],
      subtitleTracks: [RemoteTrackOption(id: '2', label: 'Anglais')],
      selectedAudioId: '1',
      selectedSubtitleId: 'no',
      downloadedFraction: 0.5,
      locked: true,
      canGoNext: true,
    );

    final message =
        RemoteProtocol.decode(RemoteProtocol.encodeState(state))
            as RemoteStateMessage;
    final decoded = message.state;

    expect(decoded.status, equals(RemotePlaybackStatus.playing));
    expect(decoded.mediaId, equals('movie-3'));
    expect(decoded.title, equals('Vaiana'));
    expect(decoded.position, equals(const Duration(minutes: 12)));
    expect(decoded.duration, equals(const Duration(hours: 1, minutes: 47)));
    expect(decoded.volume, equals(80));
    expect(decoded.audioTracks.single.label, equals('Français'));
    expect(decoded.audioTracks.single.language, equals('fre'));
    expect(decoded.subtitleTracks.single.id, equals('2'));
    expect(decoded.selectedSubtitleId, equals('no'));
    expect(decoded.downloadedFraction, equals(0.5));
    expect(decoded.locked, isTrue);
    expect(decoded.canGoNext, isTrue);
    expect(decoded.canGoPrevious, isFalse);
  });

  test('an idle state round-trips with its nulls intact', () {
    final message =
        RemoteProtocol.decode(
              RemoteProtocol.encodeState(RemotePlaybackState.idle),
            )
            as RemoteStateMessage;

    expect(message.state.status, equals(RemotePlaybackStatus.idle));
    expect(message.state.mediaId, isNull);
    expect(message.state.duration, isNull);
    expect(message.state.hasMedia, isFalse);
  });

  test('an error frame carries its code and message', () {
    final message =
        RemoteProtocol.decode(
              RemoteProtocol.encodeError('not_found', 'Film introuvable.'),
            )
            as RemoteErrorMessage;

    expect(message.code, equals('not_found'));
    expect(message.message, equals('Film introuvable.'));
  });

  group('malformed frames are dropped, not fatal', () {
    test('non-JSON decodes to null', () {
      expect(RemoteProtocol.decode('not json at all'), isNull);
    });

    test('a JSON scalar decodes to null', () {
      expect(RemoteProtocol.decode('42'), isNull);
    });

    test('an unknown kind decodes to null', () {
      expect(
        RemoteProtocol.decode(jsonEncode({'kind': 'gossip', 'payload': {}})),
        isNull,
      );
    });

    test('a missing payload decodes to null', () {
      expect(RemoteProtocol.decode(jsonEncode({'kind': 'state'})), isNull);
    });

    test('a command frame wrapping an unknown verb decodes to null', () {
      expect(
        RemoteProtocol.decode(
          jsonEncode({
            'kind': 'command',
            'payload': {'type': 'teleport'},
          }),
        ),
        isNull,
      );
    });
  });

  test('an unknown status name falls back to idle', () {
    // Forward compatibility: a host on a newer build could report a
    // status this remote does not know.
    final state = RemotePlaybackState.fromJson({'status': 'buffering'});

    expect(state.status, equals(RemotePlaybackStatus.idle));
  });
}
