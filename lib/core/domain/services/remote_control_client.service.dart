import 'package:kidflix/core/domain/model/remote_command.dart';
import 'package:kidflix/core/domain/model/remote_device.dart';
import 'package:kidflix/core/domain/model/remote_playback_state.dart';

/// Raised when a [RemoteControlClientService.query] cannot be answered.
class RemoteQueryException implements Exception {
  final String code;
  final String message;
  const RemoteQueryException(this.code, this.message);
  @override
  String toString() => 'RemoteQueryException($code): $message';
}

enum RemoteConnectionStatus {
  disconnected,
  connecting,

  /// The host rejected our token (or we had none). The user must type the
  /// six digits shown on the host.
  pairingRequired,

  connected,

  /// Transport died — host went to sleep, left the network, or refused
  /// the connection. [RemoteConnection.errorMessage] carries the reason.
  failed,
}

/// The remote's view of its link to a host.
class RemoteConnection {
  final RemoteConnectionStatus status;
  final RemoteDevice? device;

  /// Last state pushed by the host. Retains the previous snapshot while
  /// reconnecting so the UI does not blank out on a transient drop.
  final RemotePlaybackState playback;

  final String? errorMessage;

  const RemoteConnection({
    this.status = RemoteConnectionStatus.disconnected,
    this.device,
    this.playback = RemotePlaybackState.idle,
    this.errorMessage,
  });

  static const RemoteConnection disconnected = RemoteConnection();

  bool get isConnected => status == RemoteConnectionStatus.connected;

  bool get isBusy => status == RemoteConnectionStatus.connecting;

  RemoteConnection copyWith({
    RemoteConnectionStatus? status,
    RemoteDevice? device,
    RemotePlaybackState? playback,
    String? errorMessage,
    bool clearError = false,
  }) => RemoteConnection(
    status: status ?? this.status,
    device: device ?? this.device,
    playback: playback ?? this.playback,
    errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
  );
}

/// Port over the remote-side link to a host device.
abstract class RemoteControlClientService {
  /// Opens a link to [device] using the token stored for it.
  ///
  /// Settles on [RemoteConnectionStatus.pairingRequired] when no valid
  /// token exists — call [pair] then retry.
  Future<void> connect(RemoteDevice device);

  /// Exchanges the six-digit [code] shown on [device] for a durable
  /// token, stores it, and connects. Returns false when the host rejected
  /// the code.
  Future<bool> pair(RemoteDevice device, String code);

  Future<void> disconnect();

  /// Forgets the stored token for [deviceId], forcing a fresh pairing.
  Future<void> forget(String deviceId);

  /// Drops the last error message.
  ///
  /// Callers that are about to perform an action and then watch for a
  /// *new* failure use this first, so a stale message from an earlier
  /// attempt cannot be mistaken for the answer to this one.
  void clearError();

  RemoteConnection get connection;

  /// Replays the current connection to new subscribers.
  Stream<RemoteConnection> get connectionStream;

  /// Best-effort send. Silently drops when not connected — every command
  /// is a UI-driven repeatable action, so surfacing a failure per press
  /// would be noise.
  Future<void> send(RemoteCommand command);

  /// Asks the host for data the local account cannot fetch itself (the
  /// host's catalogue, a title's detail) and awaits its answer.
  ///
  /// Throws [RemoteQueryException] on failure — no connection, the host
  /// refusing, or a timeout — so a screen can show a retry rather than
  /// hanging. Success returns the raw payload for the caller to decode.
  Future<Map<String, Object?>> query(String kind, {Map<String, Object?> params});

  Future<void> dispose();
}
