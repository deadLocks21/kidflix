import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kidflix/core/application/session_state.dart';
import 'package:kidflix/core/domain/model/device.dart';
import 'package:kidflix/core/domain/model/phone_number.dart';
import 'package:kidflix/core/domain/model/profile.dart';
import 'package:kidflix/core/domain/model/session.dart';
import 'package:kidflix/infrastructure/providers/current_profile_id.provider.dart';
import 'package:kidflix/infrastructure/providers/session.controller_provider.dart';

void main() {
  group('currentProfileIdProvider', () {
    test('returns null in Anonymous state', () {
      final container = _containerFor(const Anonymous());

      expect(container.read(currentProfileIdProvider), isNull);
    });

    test('returns null in OtpRequested state', () {
      final container = _containerFor(
        OtpRequested(
          phone: PhoneNumber.parse('0612345678'),
          expiresAt: DateTime.utc(2026, 4, 27, 15),
        ),
      );

      expect(container.read(currentProfileIdProvider), isNull);
    });

    test('returns null in Authenticated state', () {
      final container = _containerFor(Authenticated(_session()));

      expect(container.read(currentProfileIdProvider), isNull);
    });

    test('returns the selected profile id in PinRequired', () {
      final session = _session();
      final ar = session.profiles.firstWhere((p) => p.id == 'ar');
      final container = _containerFor(
        PinRequired(profile: ar, session: session),
      );

      expect(container.read(currentProfileIdProvider), 'ar');
    });

    test('returns the selected profile id in ProfileSelected', () {
      final session = _session();
      final ar = session.profiles.firstWhere((p) => p.id == 'ar');
      final container = _containerFor(
        ProfileSelected(profile: ar, session: session),
      );

      expect(container.read(currentProfileIdProvider), 'ar');
    });

    test('returns the main profile id in ManagementPinRequired', () {
      final container = _containerFor(ManagementPinRequired(_session()));

      expect(container.read(currentProfileIdProvider), 'papa');
    });

    test('returns the main profile id in ManagingProfiles', () {
      final container = _containerFor(ManagingProfiles(_session()));

      expect(container.read(currentProfileIdProvider), 'papa');
    });

    test('re-emits when session state transitions', () {
      final session = _session();
      final ar = session.profiles.firstWhere((p) => p.id == 'ar');
      final controller = _MutableController(const Anonymous());
      final container = ProviderContainer(
        overrides: [
          sessionControllerProvider.overrideWith(() => controller),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(currentProfileIdProvider), isNull);

      controller.set(ProfileSelected(profile: ar, session: session));
      expect(container.read(currentProfileIdProvider), 'ar');
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

class _MutableController extends SessionController {
  _MutableController(this._initial);

  final SessionState _initial;

  @override
  SessionState build() => _initial;

  void set(SessionState next) {
    state = next;
  }
}

Session _session() => const Session(
  jwt: 'eyJabc',
  device: Device(id: 'uuid-1', name: null),
  profiles: [
    Profile(
      id: 'papa',
      name: 'Papa',
      ageCategory: AgeCategory.adulte,
      pinHash: r'$2b$12$abc',
      isMain: true,
    ),
    Profile(
      id: 'ar',
      name: 'Ar',
      ageCategory: AgeCategory.enfant,
      isMain: false,
    ),
  ],
);
