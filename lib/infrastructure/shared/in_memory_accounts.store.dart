import 'package:kidflix/core/domain/model/profile.dart';
import 'package:kidflix/core/domain/services/profile_pin.service.dart';

/// In-memory account record held by [InMemoryAccountsStore]. Mutable on
/// purpose — `profiles` is patched in place by the management repository.
class InMemoryAccount {
  final String phoneE164;
  final String jwt;
  final List<Profile> profiles;

  InMemoryAccount({
    required this.phoneE164,
    required this.jwt,
    required this.profiles,
  });
}

/// Singleton-ish store backing the InMemory auth and profile-management
/// repositories during the greenfield / offline-first phase.
///
/// Acts as a stand-in for the future backend: the accounts are seeded once
/// (fake family data), and mutations from the management repository update
/// the same list of profiles the auth repository exposes at login.
///
/// The store tracks a `currentAccountPhoneE164` set by the session
/// controller on successful OTP verification and cleared on logout. This
/// is used by the management repository when creating new profiles — the
/// "which account to add to" question answered without changing the
/// Domain interface of `ProfileManagementRepository`.
class InMemoryAccountsStore {
  final Map<String, InMemoryAccount> _accounts = {};
  String? _currentAccountPhoneE164;
  bool _seeded = false;

  /// Seeds the fake family data. Idempotent — subsequent calls are no-ops.
  /// Hashing the PINs takes ~100-300ms per call; caching the seeded state
  /// avoids repeating the work.
  Future<void> ensureSeeded(ProfilePinService pin) async {
    if (_seeded) return;
    final hashPapa = await pin.hash('1234');
    final hashRo = await pin.hash('9999');
    final hashAlice = await pin.hash('0000');

    _accounts['+33612345678'] = InMemoryAccount(
      phoneE164: '+33612345678',
      jwt: 'fake-jwt-family-test',
      profiles: [
        Profile(
          id: 'papa',
          name: 'Papa',
          ageCategory: AgeCategory.adulte,
          pinHash: hashPapa,
          isMain: true,
        ),
        const Profile(id: 'ar', name: 'Ar', ageCategory: AgeCategory.enfant),
        Profile(
          id: 'ro',
          name: 'Ro',
          ageCategory: AgeCategory.ado,
          pinHash: hashRo,
        ),
      ],
    );

    _accounts['+33787654321'] = InMemoryAccount(
      phoneE164: '+33787654321',
      jwt: 'fake-jwt-family-demo',
      profiles: [
        Profile(
          id: 'alice',
          name: 'Alice',
          ageCategory: AgeCategory.adulte,
          pinHash: hashAlice,
          isMain: true,
        ),
        const Profile(id: 'li', name: 'Li', ageCategory: AgeCategory.enfant),
      ],
    );

    _seeded = true;
  }

  InMemoryAccount? findByPhone(String e164) => _accounts[e164];

  /// Locates the account that owns the profile with [profileId], or `null`
  /// if no account contains such a profile.
  InMemoryAccount? findAccountContaining(String profileId) {
    for (final account in _accounts.values) {
      if (account.profiles.any((p) => p.id == profileId)) return account;
    }
    return null;
  }

  InMemoryAccount? get currentAccount {
    final phone = _currentAccountPhoneE164;
    if (phone == null) return null;
    return _accounts[phone];
  }

  void setCurrentAccount(String phoneE164) {
    _currentAccountPhoneE164 = phoneE164;
  }

  void clearCurrentAccount() {
    _currentAccountPhoneE164 = null;
  }
}
