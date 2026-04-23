import 'package:kidflix/core/domain/exceptions/invalid_otp.exception.dart';
import 'package:kidflix/core/domain/exceptions/otp_expired.exception.dart';
import 'package:kidflix/core/domain/exceptions/unknown_phone_number.exception.dart';
import 'package:kidflix/core/domain/model/device.dart';
import 'package:kidflix/core/domain/model/otp_code.dart';
import 'package:kidflix/core/domain/model/phone_number.dart';
import 'package:kidflix/core/domain/model/profile.dart';
import 'package:kidflix/core/domain/model/session.dart';
import 'package:kidflix/core/domain/services/auth.repository.dart';
import 'package:kidflix/core/domain/services/profile_pin.service.dart';

/// In-memory fake [AuthRepository] used until the HTTP backend is ready.
///
/// - Accepted phone numbers are hardcoded (see `_fakeAccounts`).
/// - The only valid OTP code is `"123456"`.
/// - PIN hashes are bcrypt hashes of the raw PINs, computed lazily on
///   first `verifyOtp` call so the hashing cost is paid only once.
class InMemoryAuthRepository implements AuthRepository {
  static const String _hardcodedOtp = '123456';
  static const Duration _otpValidity = Duration(minutes: 5);

  final ProfilePinService _pin;
  final Map<String, DateTime> _pendingOtpExpirations = {};
  Map<String, _FakeAccount>? _cachedAccounts;

  InMemoryAuthRepository(this._pin);

  @override
  Future<DateTime> requestOtp(PhoneNumber phoneNumber) async {
    final accounts = await _accounts();
    if (!accounts.containsKey(phoneNumber.e164)) {
      throw UnknownPhoneNumberException(phoneNumber);
    }
    final expiresAt = DateTime.now().add(_otpValidity);
    _pendingOtpExpirations[phoneNumber.e164] = expiresAt;
    return expiresAt;
  }

  @override
  Future<Session> verifyOtp(
    PhoneNumber phoneNumber,
    OtpCode code,
    Device device,
  ) async {
    final accounts = await _accounts();
    final account = accounts[phoneNumber.e164];
    if (account == null) {
      throw UnknownPhoneNumberException(phoneNumber);
    }
    final expiresAt = _pendingOtpExpirations[phoneNumber.e164];
    if (expiresAt != null && DateTime.now().isAfter(expiresAt)) {
      throw const OtpExpiredException();
    }
    if (code.value != _hardcodedOtp) {
      throw const InvalidOtpException();
    }
    _pendingOtpExpirations.remove(phoneNumber.e164);
    return Session(
      jwt: account.jwt,
      device: device,
      profiles: account.profiles,
    );
  }

  Future<Map<String, _FakeAccount>> _accounts() async {
    final cached = _cachedAccounts;
    if (cached != null) return cached;
    final hashPapa = await _pin.hash('1234');
    final hashRo = await _pin.hash('9999');
    final hashAlice = await _pin.hash('0000');
    final accounts = <String, _FakeAccount>{
      '+33612345678': _FakeAccount(
        jwt: 'fake-jwt-family-test',
        profiles: [
          Profile(
            id: 'papa',
            name: 'Papa',
            ageCategory: AgeCategory.adulte,
            pinHash: hashPapa,
          ),
          const Profile(id: 'ar', name: 'Ar', ageCategory: AgeCategory.enfant),
          Profile(
            id: 'ro',
            name: 'Ro',
            ageCategory: AgeCategory.ado,
            pinHash: hashRo,
          ),
        ],
      ),
      '+33787654321': _FakeAccount(
        jwt: 'fake-jwt-family-demo',
        profiles: [
          Profile(
            id: 'alice',
            name: 'Alice',
            ageCategory: AgeCategory.adulte,
            pinHash: hashAlice,
          ),
          const Profile(id: 'li', name: 'Li', ageCategory: AgeCategory.enfant),
        ],
      ),
    };
    _cachedAccounts = accounts;
    return accounts;
  }
}

class _FakeAccount {
  final String jwt;
  final List<Profile> profiles;

  const _FakeAccount({required this.jwt, required this.profiles});
}
