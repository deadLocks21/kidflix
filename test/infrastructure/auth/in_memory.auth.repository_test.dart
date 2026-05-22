import 'package:flutter_test/flutter_test.dart';
import 'package:kidflix/core/domain/model/device.dart';
import 'package:kidflix/core/domain/model/otp_code.dart';
import 'package:kidflix/core/domain/model/phone_number.dart';
import 'package:kidflix/infrastructure/auth/in_memory.auth.repository.dart';
import 'package:kidflix/infrastructure/pin/bcrypt.profile_pin.service.dart';
import 'package:kidflix/infrastructure/shared/in_memory_accounts.store.dart';

void main() {
  group('InMemoryAuthRepository.fetchProfiles', () {
    test('returns the seeded profiles for the logged-in number', () async {
      final repo = InMemoryAuthRepository(
        BcryptProfilePinService(),
        InMemoryAccountsStore(),
      );
      await repo.requestOtp(PhoneNumber.parse('0612345678'));
      await repo.verifyOtp(
        PhoneNumber.parse('0612345678'),
        OtpCode.parse('123456'),
        const Device(id: 'd1', name: null),
      );

      final profiles = await repo.fetchProfiles();

      expect(
        profiles.map((p) => p.id),
        containsAllInOrder(['papa', 'ar', 'ro']),
      );
      expect(profiles.firstWhere((p) => p.id == 'papa').isMain, isTrue);
    });

    test(
      'throws StateError when called before any successful verifyOtp',
      () async {
        final repo = InMemoryAuthRepository(
          BcryptProfilePinService(),
          InMemoryAccountsStore(),
        );

        await expectLater(repo.fetchProfiles(), throwsStateError);
      },
    );
  });
}
