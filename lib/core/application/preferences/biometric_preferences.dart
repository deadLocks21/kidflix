/// Application-layer abstraction for the parent's per-profile opt-in to
/// biometric unlock. The Domain layer does NOT depend on
/// `SharedPreferences` directly — this interface decouples the policy
/// from its persistence (in `lib/infrastructure/preferences/`).
///
/// Keyed by `profileId`: the flag is **device-local** on purpose
/// (biometrics are bound to the device, so the opt-in must not sync to
/// other devices). The main profile's flag governs both the profile
/// unlock gate and the management gate, since both verify the main
/// profile's PIN.
///
/// Default value: `false`. Biometric unlock is opt-in.
abstract interface class BiometricPreferences {
  Future<bool> isEnabledForProfile(String profileId);
  Future<void> setEnabledForProfile(String profileId, bool enabled);
}
