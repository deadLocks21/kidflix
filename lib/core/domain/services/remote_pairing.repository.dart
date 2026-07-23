/// Persistence for remote-control pairing secrets.
///
/// Two symmetric halves, because one install is both things at different
/// moments: as a *remote* it stores one token per host it has paired
/// with; as a *host* it stores the set of tokens it has handed out.
///
/// Tokens are LAN-scoped bearer secrets for a family media app, not
/// account credentials — `SharedPreferences` is the right weight here.
abstract class RemotePairingRepository {
  /// Token previously obtained from the host with [hostDeviceId], or null
  /// when that host was never paired.
  Future<String?> findTokenForHost(String hostDeviceId);

  Future<void> saveTokenForHost({
    required String hostDeviceId,
    required String token,
  });

  Future<void> deleteTokenForHost(String hostDeviceId);

  /// Tokens this device has issued to remotes and still honours.
  Future<Set<String>> loadIssuedTokens();

  Future<void> addIssuedToken(String token);

  /// Revokes every remote. Used by the "forget all remotes" action.
  Future<void> clearIssuedTokens();
}
