import 'package:kidflix/core/domain/exceptions/invalid_otp.exception.dart';
import 'package:kidflix/core/domain/exceptions/otp_expired.exception.dart';
import 'package:kidflix/core/domain/exceptions/unknown_phone_number.exception.dart';
import 'package:kidflix/core/domain/model/device.dart';
import 'package:kidflix/core/domain/model/otp_code.dart';
import 'package:kidflix/core/domain/model/phone_number.dart';
import 'package:kidflix/core/domain/model/session.dart';
import 'package:kidflix/core/domain/services/auth.repository.dart';
import 'package:kidflix/core/domain/services/profile_pin.service.dart';
import 'package:kidflix/infrastructure/shared/in_memory_accounts.store.dart';

/// In-memory fake [AuthRepository] used until the HTTP backend is ready.
///
/// - Accepted phone numbers are those seeded in [InMemoryAccountsStore].
/// - The only valid OTP code is `"123456"`.
/// - On successful verification, the store is told which account is the
///   currently active one so the profile-management repository knows
///   where to create new profiles.
class InMemoryAuthRepository implements AuthRepository {
  static const String _hardcodedOtp = '123456';
  static const Duration _otpValidity = Duration(minutes: 5);

  final ProfilePinService _pin;
  final InMemoryAccountsStore _store;
  final Map<String, DateTime> _pendingOtpExpirations = {};

  InMemoryAuthRepository(this._pin, this._store);

  @override
  Future<DateTime> requestOtp(PhoneNumber phoneNumber) async {
    await _store.ensureSeeded(_pin);
    final account = _store.findByPhone(phoneNumber.e164);
    if (account == null) {
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
    await _store.ensureSeeded(_pin);
    final account = _store.findByPhone(phoneNumber.e164);
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
    _store.setCurrentAccount(account.phoneE164);
    return Session(
      jwt: account.jwt,
      device: device,
      profiles: List.unmodifiable(account.profiles),
    );
  }
}
