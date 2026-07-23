import 'package:flutter_test/flutter_test.dart';
import 'package:kidflix/core/application/remote/remote_protocol.dart';
import 'package:kidflix/core/domain/model/remote_playback_state.dart';
import 'package:kidflix/core/domain/model/remote_session.dart';

const _profiles = [
  RemoteProfileOption(id: 'p1', name: 'Ariane', avatarId: 'a-07'),
  RemoteProfileOption(
    id: 'p2',
    name: 'Timh',
    avatarId: 'a-10',
    requiresPin: true,
    isMain: true,
  ),
];

void main() {
  group('RemoteSessionSnapshot', () {
    test('survives a full frame round-trip', () {
      const state = RemotePlaybackState(
        session: RemoteSessionSnapshot(
          stage: RemoteSessionStage.pinRequired,
          profiles: _profiles,
          pendingProfileId: 'p2',
        ),
      );

      final message =
          RemoteProtocol.decode(RemoteProtocol.encodeState(state))
              as RemoteStateMessage;
      final session = message.state.session;

      expect(session.stage, equals(RemoteSessionStage.pinRequired));
      expect(session.pendingProfileId, equals('p2'));
      expect(session.profiles, hasLength(2));
      expect(session.profiles.first.name, equals('Ariane'));
      expect(session.profiles.first.requiresPin, isFalse);
      expect(session.profiles.last.requiresPin, isTrue);
      expect(session.profiles.last.isMain, isTrue);
      expect(session.profiles.last.avatarId, equals('a-10'));
    });

    test('never carries anything PIN-derived on the wire', () {
      const session = RemoteSessionSnapshot(
        stage: RemoteSessionStage.profileSelection,
        profiles: _profiles,
      );

      // The hash stays on the host: a captured frame must not hand an
      // attacker something to grind offline.
      final encoded = RemoteProtocol.encodeState(
        const RemotePlaybackState(session: session),
      );

      expect(encoded, isNot(contains('pinHash')));
      expect(encoded, isNot(contains(r'$2b$')));
    });

    test('isReady only in the ready stage', () {
      for (final stage in RemoteSessionStage.values) {
        final session = RemoteSessionSnapshot(stage: stage);
        expect(session.isReady, equals(stage == RemoteSessionStage.ready));
      }
    });

    test('needsAttention marks the stages a remote can act on', () {
      bool needs(RemoteSessionStage stage) =>
          RemoteSessionSnapshot(stage: stage).needsAttention;

      expect(needs(RemoteSessionStage.profileSelection), isTrue);
      expect(needs(RemoteSessionStage.pinRequired), isTrue);
      // Nothing a remote can do: the SMS sign-in needs the host itself.
      expect(needs(RemoteSessionStage.anonymous), isFalse);
      expect(needs(RemoteSessionStage.ready), isFalse);
    });

    test('profileById finds a profile and tolerates a null id', () {
      const session = RemoteSessionSnapshot(profiles: _profiles);

      expect(session.profileById('p2')?.name, equals('Timh'));
      expect(session.profileById('nope'), isNull);
      expect(session.profileById(null), isNull);
    });

    test('an unknown stage falls back to anonymous', () {
      // Forward compatibility with a host on a newer build.
      final session = RemoteSessionSnapshot.fromJson({'stage': 'rebooting'});

      expect(session.stage, equals(RemoteSessionStage.anonymous));
    });

    test('a frame from a host predating profile control decodes safely', () {
      // No `session` key at all — that host simply cannot be driven this
      // way, and must not crash the remote decoding its state.
      final state = RemotePlaybackState.fromJson({
        'status': 'playing',
        'mediaId': 'm1',
      });

      expect(state.session.stage, equals(RemoteSessionStage.anonymous));
      expect(state.session.profiles, isEmpty);
      expect(state.mediaId, equals('m1'));
    });

    test('a malformed profile entry is skipped, not fatal', () {
      final session = RemoteSessionSnapshot.fromJson({
        'stage': 'profileSelection',
        'profiles': [
          {'id': 'p1', 'name': 'Ariane'},
          'not-a-map',
          {'id': 'p3', 'name': 'Rose', 'requiresPin': true},
        ],
      });

      expect(session.profiles, hasLength(2));
      expect(session.profiles.last.name, equals('Rose'));
    });
  });
}
