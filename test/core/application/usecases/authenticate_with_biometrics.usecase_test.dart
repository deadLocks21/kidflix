import 'package:flutter_test/flutter_test.dart';
import 'package:kidflix/core/application/preferences/biometric_preferences.dart';
import 'package:kidflix/core/application/services/logger_application.service.dart';
import 'package:kidflix/core/application/usecases/authenticate_with_biometrics.usecase.dart';
import 'package:kidflix/core/domain/services/biometric_auth.service.dart';
import 'package:kidflix/infrastructure/logger/in_memory.logger.service.dart';

class _FakePrefs implements BiometricPreferences {
  final Map<String, bool> _store;
  _FakePrefs([Map<String, bool>? initial]) : _store = {...?initial};

  @override
  Future<bool> isEnabledForProfile(String profileId) async =>
      _store[profileId] ?? false;

  @override
  Future<void> setEnabledForProfile(String profileId, bool enabled) async =>
      _store[profileId] = enabled;
}

class _FakeBiometrics implements BiometricAuthService {
  final bool available;
  final bool authResult;
  int authenticateCalls = 0;

  _FakeBiometrics({this.available = true, this.authResult = true});

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<bool> authenticate({required String reason}) async {
    authenticateCalls++;
    return authResult;
  }
}

AuthenticateWithBiometricsUseCase _build(
  _FakePrefs prefs,
  _FakeBiometrics biometrics,
) => AuthenticateWithBiometricsUseCase(
  prefs,
  biometrics,
  LoggerApplicationService(InMemoryLoggerService()),
);

void main() {
  group('isOfferedFor', () {
    test('false when the profile has not opted-in (skips availability)', () async {
      final biometrics = _FakeBiometrics(available: true);
      final usecase = _build(_FakePrefs(), biometrics);
      expect(await usecase.isOfferedFor('p1'), isFalse);
    });

    test('false when opted-in but device unavailable', () async {
      final usecase = _build(
        _FakePrefs({'p1': true}),
        _FakeBiometrics(available: false),
      );
      expect(await usecase.isOfferedFor('p1'), isFalse);
    });

    test('true when opted-in and available', () async {
      final usecase = _build(
        _FakePrefs({'p1': true}),
        _FakeBiometrics(available: true),
      );
      expect(await usecase.isOfferedFor('p1'), isTrue);
    });
  });

  group('execute', () {
    test('does not prompt when not offered', () async {
      final biometrics = _FakeBiometrics(available: false);
      final usecase = _build(_FakePrefs({'p1': true}), biometrics);
      final ok = await usecase.execute(profileId: 'p1', reason: 'unlock');
      expect(ok, isFalse);
      expect(biometrics.authenticateCalls, 0);
    });

    test('returns false when biometric prompt is declined', () async {
      final usecase = _build(
        _FakePrefs({'p1': true}),
        _FakeBiometrics(available: true, authResult: false),
      );
      expect(
        await usecase.execute(profileId: 'p1', reason: 'unlock'),
        isFalse,
      );
    });

    test('returns true when offered and authenticated', () async {
      final biometrics = _FakeBiometrics(available: true, authResult: true);
      final usecase = _build(_FakePrefs({'p1': true}), biometrics);
      final ok = await usecase.execute(profileId: 'p1', reason: 'unlock');
      expect(ok, isTrue);
      expect(biometrics.authenticateCalls, 1);
    });
  });
}
