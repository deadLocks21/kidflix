import 'package:kidflix/core/domain/model/device.dart';
import 'package:kidflix/core/domain/model/phone_number.dart';
import 'package:kidflix/core/domain/model/session.dart';

/// Contract for persisting a [Session] across application restarts.
///
/// Implementations live in `lib/infrastructure/session/`.
abstract interface class SessionRepository {
  /// Reads the persisted session. Returns `null` when no session has been
  /// persisted yet, or when the persisted data is incomplete/corrupt.
  Future<Session?> read();

  /// Persists [session]. Overwrites any previously persisted session.
  Future<void> write(Session session);

  /// Reads the phone number the current session was established with, or
  /// `null` if none was persisted (fresh install, or session written by a
  /// build predating this field).
  ///
  /// The backend never returns the phone in `verify-otp`, so the client
  /// persists it itself at login time. It is what allows the silent
  /// re-authentication flow to fire a new OTP on `401 invalid_token`
  /// without asking the user to retype their number.
  Future<PhoneNumber?> readPhoneNumber();

  /// Persists [phone] as the number backing the current session.
  Future<void> writePhoneNumber(PhoneNumber phone);

  /// Clears session data (JWT, profiles, phone number) while preserving the
  /// device id. Called on logout and when partial/corrupt data is detected.
  ///
  /// Callers that need the phone afterwards (silent re-auth) must
  /// [readPhoneNumber] *before* calling this.
  Future<void> clearSessionPreserveDevice();

  /// Clears everything, including the device id. Not used by the current
  /// flow but exposed for completeness (e.g. "wipe this installation").
  Future<void> clear();

  /// Reads the persisted [Device]; generates a new UUID-based device at
  /// first call and persists it.
  Future<Device> readOrCreateDevice();
}
