import 'package:kidflix/core/application/remote/remote_query.dart';
import 'package:kidflix/core/domain/model/remote_command.dart';
import 'package:kidflix/core/domain/model/remote_playback_state.dart';

/// Observable state of the local control server.
class RemoteHostStatus {
  final bool running;

  /// Port actually bound — may differ from the default when it was taken.
  final int? port;

  /// LAN addresses this host is reachable at, for the "pair by hand"
  /// escape hatch when mDNS is blocked (guest Wi-Fi, AP isolation…).
  final List<String> addresses;

  /// Six digits the user types on the remote to pair. Rotated on every
  /// [RemoteControlHostService.start] so a code glimpsed once does not
  /// stay valid forever.
  final String pairingCode;

  final int connectedRemotes;

  /// Set when the server could not bind or advertise.
  final String? errorMessage;

  const RemoteHostStatus({
    this.running = false,
    this.port,
    this.addresses = const [],
    this.pairingCode = '',
    this.connectedRemotes = 0,
    this.errorMessage,
  });

  static const RemoteHostStatus stopped = RemoteHostStatus();

  RemoteHostStatus copyWith({
    bool? running,
    int? port,
    List<String>? addresses,
    String? pairingCode,
    int? connectedRemotes,
    String? errorMessage,
    bool clearError = false,
  }) => RemoteHostStatus(
    running: running ?? this.running,
    port: port ?? this.port,
    addresses: addresses ?? this.addresses,
    pairingCode: pairingCode ?? this.pairingCode,
    connectedRemotes: connectedRemotes ?? this.connectedRemotes,
    errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
  );
}

/// Port over the on-device control server.
///
/// Owns the socket and the mDNS advertisement; knows nothing about the
/// player. Commands surface on [commands] for the application layer to
/// apply, and the resulting state is pushed back through [publishState].
abstract class RemoteControlHostService {
  /// Binds the socket and starts advertising. Idempotent — starting an
  /// already-running host returns the current status untouched (notably
  /// keeping the pairing code stable).
  Future<RemoteHostStatus> start();

  /// Closes every remote connection, unbinds and stops advertising.
  Future<void> stop();

  RemoteHostStatus get status;

  /// Replays the current status to new subscribers.
  Stream<RemoteHostStatus> get statusStream;

  /// Commands received from any connected remote, in arrival order.
  Stream<RemoteCommand> get commands;

  /// Data requests received from remotes — a remote asking the host to
  /// read something on its behalf (its catalogue, a title's detail),
  /// which the remote's own account is not allowed to fetch.
  Stream<RemoteQuery> get queries;

  /// Answers a [RemoteQuery], routed back to the remote that asked by
  /// its `queryId`.
  void answerQuery(RemoteQueryResult result);

  /// Pushes [state] to every connected remote. Cheap to call on every
  /// position tick — implementations coalesce and skip no-op pushes.
  void publishState(RemotePlaybackState state);

  /// Reports a command that could not be honoured (unknown title, no
  /// player mounted…) so the remote can surface it.
  void reportError(String code, String message);

  Future<void> dispose();
}
