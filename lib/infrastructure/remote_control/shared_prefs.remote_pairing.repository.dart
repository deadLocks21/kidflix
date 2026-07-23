import 'package:kidflix/core/domain/services/remote_pairing.repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Prefix for the per-host token this device holds as a *remote*. Full
/// key is `remote.token.<hostDeviceId>`.
const String remoteHostTokenKeyPrefix = 'remote.token.';

/// Tokens this device has issued as a *host*, stored as a string list.
const String remoteIssuedTokensKey = 'remote.issued_tokens';

String remoteHostTokenKey(String hostDeviceId) =>
    '$remoteHostTokenKeyPrefix$hostDeviceId';

class SharedPrefsRemotePairingRepository implements RemotePairingRepository {
  final Future<SharedPreferences> Function() _resolvePrefs;

  SharedPrefsRemotePairingRepository({
    Future<SharedPreferences> Function()? resolvePrefs,
  }) : _resolvePrefs = resolvePrefs ?? SharedPreferences.getInstance;

  @override
  Future<String?> findTokenForHost(String hostDeviceId) async {
    final prefs = await _resolvePrefs();
    return prefs.getString(remoteHostTokenKey(hostDeviceId));
  }

  @override
  Future<void> saveTokenForHost({
    required String hostDeviceId,
    required String token,
  }) async {
    final prefs = await _resolvePrefs();
    await prefs.setString(remoteHostTokenKey(hostDeviceId), token);
  }

  @override
  Future<void> deleteTokenForHost(String hostDeviceId) async {
    final prefs = await _resolvePrefs();
    await prefs.remove(remoteHostTokenKey(hostDeviceId));
  }

  @override
  Future<Set<String>> loadIssuedTokens() async {
    final prefs = await _resolvePrefs();
    return (prefs.getStringList(remoteIssuedTokensKey) ?? const []).toSet();
  }

  @override
  Future<void> addIssuedToken(String token) async {
    final prefs = await _resolvePrefs();
    final current = prefs.getStringList(remoteIssuedTokensKey) ?? const [];
    if (current.contains(token)) return;
    // Keep the list bounded: a household pairs a handful of devices, and
    // an unbounded list would grow forever as remotes are re-paired.
    final next = [...current, token];
    const maxTokens = 20;
    await prefs.setStringList(
      remoteIssuedTokensKey,
      next.length <= maxTokens
          ? next
          : next.sublist(next.length - maxTokens),
    );
  }

  @override
  Future<void> clearIssuedTokens() async {
    final prefs = await _resolvePrefs();
    await prefs.remove(remoteIssuedTokensKey);
  }
}
