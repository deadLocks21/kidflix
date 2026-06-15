/// Contract for device biometric authentication (fingerprint / face).
///
/// The implementation lives in `lib/infrastructure/biometric/`. On
/// iOS and Android it bridges to the OS prompt via the `local_auth`
/// plugin. On other platforms a noop fallback is used.
///
/// Biometric unlock is a *convenience layer on top of the existing PIN
/// gate*, never a replacement: it short-circuits the same
/// `PinRequired -> ProfileSelected` (and `ManagementPinRequired ->
/// ManagingProfiles`) transitions, and the 4-digit PIN remains the
/// fallback whenever biometrics are declined or unavailable.
///
/// Both methods complete with a `bool` and never throw — the caller
/// reacts to the boolean, not to exceptions (same philosophy as
/// `KidsLockService`).
abstract interface class BiometricAuthService {
  /// `true` when the device supports biometrics **and** at least one is
  /// enrolled. `false` on unsupported platforms, when no biometric is
  /// enrolled, or on any error.
  Future<bool> isAvailable();

  /// Prompts the OS biometric sheet. Returns `true` only when the user
  /// successfully authenticates with a biometric. Returns `false` when
  /// declined, cancelled, locked out, unavailable, or on any error.
  ///
  /// [reason] is the localized sentence shown to the user (e.g. iOS
  /// Face ID prompt subtitle).
  Future<bool> authenticate({required String reason});
}
