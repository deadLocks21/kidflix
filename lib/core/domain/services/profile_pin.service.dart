/// Contract for hashing and verifying profile PINs.
///
/// Production implementation uses `bcrypt`. Implementations live in
/// `lib/infrastructure/pin/`.
abstract interface class ProfilePinService {
  /// Returns a bcrypt hash of [rawPin]. Used to seed in-memory fake data.
  Future<String> hash(String rawPin);

  /// Returns `true` when [rawPin] matches [bcryptHash].
  Future<bool> verify(String rawPin, String bcryptHash);
}
