import 'package:flutter_test/flutter_test.dart';
import 'package:kidflix/core/application/usecases/refresh_profiles.usecase.dart';
import 'package:kidflix/core/domain/model/device.dart';
import 'package:kidflix/core/domain/model/otp_code.dart';
import 'package:kidflix/core/domain/model/phone_number.dart';
import 'package:kidflix/core/domain/model/profile.dart';
import 'package:kidflix/core/domain/model/session.dart';
import 'package:kidflix/core/domain/services/auth.repository.dart';

class _FakeAuthRepository implements AuthRepository {
  final List<Profile> profiles;
  Object? error;
  int callCount = 0;

  _FakeAuthRepository(this.profiles, {this.error});

  @override
  Future<DateTime> requestOtp(PhoneNumber phoneNumber) async =>
      throw UnimplementedError();

  @override
  Future<Session> verifyOtp(
    PhoneNumber phoneNumber,
    OtpCode code,
    Device device,
  ) async => throw UnimplementedError();

  @override
  Future<List<Profile>> fetchProfiles() async {
    callCount += 1;
    final err = error;
    if (err != null) throw err;
    return profiles;
  }
}

void main() {
  group('RefreshProfilesUseCase', () {
    test('forwards to AuthRepository.fetchProfiles and returns the result',
        () async {
      final repo = _FakeAuthRepository(const [
        Profile(
          id: 'papa',
          name: 'Papa',
          ageCategory: AgeCategory.adulte,
          isMain: true,
        ),
        Profile(
          id: 'ar',
          name: 'Ar',
          ageCategory: AgeCategory.enfant,
        ),
      ]);
      final useCase = RefreshProfilesUseCase(repo);

      final result = await useCase.execute();

      expect(repo.callCount, 1);
      expect(result.map((p) => p.id), ['papa', 'ar']);
    });

    test('propagates exceptions from the repository', () async {
      final repo = _FakeAuthRepository(const [], error: Exception('boom'));
      final useCase = RefreshProfilesUseCase(repo);

      await expectLater(useCase.execute(), throwsA(isA<Exception>()));
    });

    test('returns an empty list when the repository has none', () async {
      final repo = _FakeAuthRepository(const []);
      final useCase = RefreshProfilesUseCase(repo);

      expect(await useCase.execute(), isEmpty);
    });
  });
}
