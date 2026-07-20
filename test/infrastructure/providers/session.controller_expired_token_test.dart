import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kidflix/core/application/session_state.dart';
import 'package:kidflix/core/domain/exceptions/unknown_phone_number.exception.dart';
import 'package:kidflix/core/domain/model/device.dart';
import 'package:kidflix/core/domain/model/otp_code.dart';
import 'package:kidflix/core/domain/model/phone_number.dart';
import 'package:kidflix/core/domain/model/profile.dart';
import 'package:kidflix/core/domain/model/session.dart';
import 'package:kidflix/core/domain/services/auth.repository.dart';
import 'package:kidflix/core/domain/services/session.repository.dart';
import 'package:kidflix/infrastructure/providers/auth.repository_provider.dart';
import 'package:kidflix/infrastructure/providers/session.controller_provider.dart';
import 'package:kidflix/infrastructure/providers/session.repository_provider.dart';
import 'package:kidflix/infrastructure/session/in_memory.session.repository.dart';

void main() {
  group('SessionController.handleExpiredToken', () {
    test(
      're-issues an OTP and lands on OtpRequested(sessionExpired)',
      () async {
        final harness = await _Harness.authenticated();

        await harness.controller.handleExpiredToken();

        expect(harness.auth.otpRequests, [_phone]);
        final state = harness.container.read(sessionControllerProvider);
        expect(state, isA<OtpRequested>());
        expect((state as OtpRequested).phone, _phone);
        expect(state.sessionExpired, isTrue);
      },
    );

    test('wipes the dead session from storage', () async {
      final harness = await _Harness.authenticated();

      await harness.controller.handleExpiredToken();

      expect(await harness.sessions.read(), isNull);
    });

    test('keeps the phone persisted for the next login', () async {
      final harness = await _Harness.authenticated();

      await harness.controller.handleExpiredToken();

      expect(await harness.sessions.readPhoneNumber(), _phone);
    });

    test('sends a single SMS when many requests 401 at once', () async {
      final harness = await _Harness.authenticated();

      await Future.wait([
        harness.controller.handleExpiredToken(),
        harness.controller.handleExpiredToken(),
        harness.controller.handleExpiredToken(),
        harness.controller.handleExpiredToken(),
        harness.controller.handleExpiredToken(),
      ]);

      expect(harness.auth.otpRequests, hasLength(1));
    });

    test('releases the single-flight lock after completing', () async {
      final harness = await _Harness.authenticated();

      await harness.controller.handleExpiredToken();
      // A later expiry (new session, new 401) must be able to recover too.
      harness.controller.state = Authenticated(_session);
      await harness.controller.handleExpiredToken();

      expect(harness.auth.otpRequests, hasLength(2));
    });

    test('falls back to Anonymous when no phone was ever persisted', () async {
      final harness = await _Harness.authenticated(persistPhone: false);

      await harness.controller.handleExpiredToken();

      expect(harness.auth.otpRequests, isEmpty);
      expect(
        harness.container.read(sessionControllerProvider),
        isA<Anonymous>(),
      );
    });

    test('falls back to Anonymous when the SMS send fails', () async {
      final harness = await _Harness.authenticated();
      harness.auth.failWith = _NetworkFailure();

      await harness.controller.handleExpiredToken();

      expect(
        harness.container.read(sessionControllerProvider),
        isA<Anonymous>(),
      );
    });

    test('falls back to Anonymous when the phone is no longer known', () async {
      final harness = await _Harness.authenticated();
      harness.auth.failWith = UnknownPhoneNumberException(_phone);

      await harness.controller.handleExpiredToken();

      expect(
        harness.container.read(sessionControllerProvider),
        isA<Anonymous>(),
      );
    });

    test('is a no-op from Anonymous (late 401 after logout)', () async {
      final harness = await _Harness.from(const Anonymous());

      await harness.controller.handleExpiredToken();

      expect(harness.auth.otpRequests, isEmpty);
      expect(
        harness.container.read(sessionControllerProvider),
        isA<Anonymous>(),
      );
    });

    test('is a no-op from OtpRequested (does not re-arm the flow)', () async {
      final harness = await _Harness.from(
        OtpRequested(phone: _phone, expiresAt: DateTime.utc(2026, 4, 27, 15)),
      );

      await harness.controller.handleExpiredToken();

      expect(harness.auth.otpRequests, isEmpty);
    });

    test('recovers from ProfileSelected too, not just Authenticated', () async {
      final harness = await _Harness.authenticated(
        state: ProfileSelected(
          profile: _session.profiles.first,
          session: _session,
        ),
      );

      await harness.controller.handleExpiredToken();

      expect(
        harness.container.read(sessionControllerProvider),
        isA<OtpRequested>(),
      );
    });
  });
}

/// Wires a real [SessionController] over a fake auth repository and an
/// in-memory session store, so `handleExpiredToken` runs its production
/// code path end-to-end.
class _Harness {
  _Harness({
    required this.container,
    required this.auth,
    required this.sessions,
  });

  final ProviderContainer container;
  final _FakeAuthRepository auth;
  final SessionRepository sessions;

  SessionController get controller =>
      container.read(sessionControllerProvider.notifier);

  static Future<_Harness> from(SessionState state) async {
    final auth = _FakeAuthRepository();
    final sessions = InMemorySessionRepository();
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        sessionRepositoryProvider.overrideWithValue(sessions),
        sessionControllerProvider.overrideWith(() => _SeededController(state)),
      ],
    );
    addTearDown(container.dispose);
    return _Harness(container: container, auth: auth, sessions: sessions);
  }

  /// Seeds a live session in storage — the situation right before the JWT
  /// goes stale server-side.
  static Future<_Harness> authenticated({
    bool persistPhone = true,
    SessionState? state,
  }) async {
    final harness = await _Harness.from(state ?? Authenticated(_session));
    await harness.sessions.write(_session);
    if (persistPhone) {
      await harness.sessions.writePhoneNumber(_phone);
    }
    return harness;
  }
}

/// Exposes `state` so a test can simulate a second login cycle.
class _SeededController extends SessionController {
  _SeededController(this._seed);

  final SessionState _seed;

  @override
  SessionState build() => _seed;
}

class _NetworkFailure implements Exception {}

class _FakeAuthRepository implements AuthRepository {
  final List<PhoneNumber> otpRequests = [];
  Object? failWith;

  @override
  Future<DateTime> requestOtp(PhoneNumber phoneNumber) async {
    otpRequests.add(phoneNumber);
    final failure = failWith;
    if (failure != null) throw failure;
    return DateTime.utc(2026, 4, 27, 15, 5);
  }

  @override
  Future<Session> verifyOtp(
    PhoneNumber phoneNumber,
    OtpCode code,
    Device device,
  ) async => throw UnimplementedError();

  @override
  Future<List<Profile>> fetchProfiles() async => throw UnimplementedError();
}

final PhoneNumber _phone = PhoneNumber.parse('0612345678');

final Session _session = Session(
  jwt: 'eyJstale',
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
