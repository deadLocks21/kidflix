import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kidflix/core/application/session_state.dart';
import 'package:kidflix/core/domain/model/device.dart';
import 'package:kidflix/core/domain/model/phone_number.dart';
import 'package:kidflix/core/domain/model/profile.dart';
import 'package:kidflix/core/domain/model/session.dart';
import 'package:kidflix/infrastructure/providers/current_session.provider.dart';
import 'package:kidflix/infrastructure/providers/session.controller_provider.dart';

void main() {
  group('currentSessionProvider', () {
    test('returns null in Anonymous state', () {
      final container = _containerFor(const Anonymous());

      expect(container.read(currentSessionProvider), isNull);
    });

    test('returns null in OtpRequested state', () {
      final container = _containerFor(
        OtpRequested(
          phone: PhoneNumber.parse('0612345678'),
          expiresAt: DateTime.utc(2026, 4, 27, 15),
        ),
      );

      expect(container.read(currentSessionProvider), isNull);
    });

    test('returns the session in Authenticated state', () {
      final session = _session();
      final container = _containerFor(Authenticated(session));

      expect(container.read(currentSessionProvider), same(session));
    });

    test('returns the session in PinRequired state', () {
      final session = _session();
      final container = _containerFor(
        PinRequired(profile: session.profiles.first, session: session),
      );

      expect(container.read(currentSessionProvider), same(session));
    });

    test('returns the session in ProfileSelected state', () {
      final session = _session();
      final container = _containerFor(
        ProfileSelected(profile: session.profiles.first, session: session),
      );

      expect(container.read(currentSessionProvider), same(session));
    });

    test('returns the session in ManagementPinRequired state', () {
      final session = _session();
      final container = _containerFor(ManagementPinRequired(session));

      expect(container.read(currentSessionProvider), same(session));
    });

    test('returns the session in ManagingProfiles state', () {
      final session = _session();
      final container = _containerFor(ManagingProfiles(session));

      expect(container.read(currentSessionProvider), same(session));
    });
  });
}

ProviderContainer _containerFor(SessionState state) {
  final container = ProviderContainer(
    overrides: [
      sessionControllerProvider.overrideWith(() => _StubController(state)),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

class _StubController extends SessionController {
  _StubController(this._state);

  final SessionState _state;

  @override
  SessionState build() => _state;
}

Session _session() => Session(
  jwt: 'eyJabc',
  device: const Device(id: 'uuid-1', name: null),
  profiles: const [
    Profile(
      id: 'papa',
      name: 'Papa',
      ageCategory: AgeCategory.adulte,
      pinHash: r'$2b$12$abc',
      isMain: true,
    ),
  ],
);
