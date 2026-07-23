import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:kidflix/core/application/remote/remote_protocol.dart';
import 'package:kidflix/core/application/remote/remote_query.dart';
import 'package:kidflix/core/application/services/logger_application.service.dart';
import 'package:kidflix/core/domain/model/remote_command.dart';
import 'package:kidflix/core/domain/model/remote_device.dart';
import 'package:kidflix/core/domain/model/remote_playback_state.dart';
import 'package:kidflix/core/domain/services/remote_control_client.service.dart';
import 'package:kidflix/core/domain/services/remote_pairing.repository.dart';

const Duration _httpTimeout = Duration(seconds: 5);
const Duration _reconnectDelay = Duration(seconds: 2);

/// A host catalogue query has to hit the backend, so it gets longer than
/// the socket timeouts — but still bounded, so a wedged host surfaces a
/// retry instead of an endless spinner.
const Duration _queryTimeout = Duration(seconds: 12);

/// How many times a dropped link is retried before giving up.
///
/// A host that locks its screen or drops off Wi-Fi for a moment should
/// not force the user back through the device picker; a host that is
/// genuinely gone should not leave a spinner up forever.
const int _maxReconnectAttempts = 3;

/// `dart:io` WebSocket implementation of the remote side.
///
/// Uses a bare [HttpClient] rather than the app's shared `dio` instance
/// on purpose: that one carries an interceptor injecting the backend JWT
/// and device headers, none of which belong on a LAN peer request.
class WsRemoteControlClientService implements RemoteControlClientService {
  final RemotePairingRepository _pairing;
  final LoggerApplicationService _logger;

  WsRemoteControlClientService({
    required RemotePairingRepository pairing,
    required LoggerApplicationService logger,
  }) : _pairing = pairing,
       _logger = logger;

  final _controller = StreamController<RemoteConnection>.broadcast();

  /// In-flight queries awaiting a host answer, keyed by query id.
  final _pendingQueries = <String, Completer<RemoteQueryResult>>{};
  int _queryCounter = 0;

  WebSocket? _socket;
  StreamSubscription<dynamic>? _socketSub;
  RemoteConnection _connection = RemoteConnection.disconnected;
  int _reconnectAttempts = 0;
  Timer? _reconnectTimer;

  /// Guards against a reconnect firing after the user disconnected.
  bool _wantConnection = false;
  bool _disposed = false;

  @override
  RemoteConnection get connection => _connection;

  @override
  Stream<RemoteConnection> get connectionStream async* {
    yield _connection;
    yield* _controller.stream;
  }

  @override
  Future<void> connect(RemoteDevice device) async {
    _wantConnection = true;
    _reconnectAttempts = 0;
    await _openSocket(await _resolveReachable(device));
  }

  /// Returns [device] pinned to whichever advertised address answers.
  ///
  /// mDNS lists every interface a host has, including virtual ones a
  /// VPN or a container runtime added, and the first is not necessarily
  /// routable from here. Probing the unauthenticated `/info` endpoint is
  /// cheap and turns "injoignable" into "connected" on exactly the
  /// machines most likely to hit it — developer laptops.
  Future<RemoteDevice> _resolveReachable(RemoteDevice device) async {
    final candidates = device.allHosts;
    if (candidates.length <= 1) return device;
    for (final candidate in candidates) {
      if (await _probeInfo(device.baseUrlFor(candidate))) {
        if (candidate != device.host) {
          unawaited(
            _logger.info(
              'remote.client.address_fallback',
              attrs: {'host': candidate},
            ),
          );
        }
        return device.copyWith(host: candidate);
      }
    }
    // None answered — keep the advertised one so the failure message
    // names the address the user would recognise.
    return device;
  }

  Future<void> _openSocket(RemoteDevice device) async {
    if (_disposed) return;
    await _closeSocket();
    _emit(
      RemoteConnection(
        status: RemoteConnectionStatus.connecting,
        device: device,
        playback: _connection.device?.id == device.id
            ? _connection.playback
            : const RemotePlaybackState(),
      ),
    );

    final token = await _pairing.findTokenForHost(device.id);
    if (token == null) {
      _emit(
        RemoteConnection(
          status: RemoteConnectionStatus.pairingRequired,
          device: device,
        ),
      );
      return;
    }

    final url = Uri.parse(
      '${device.baseUrl}${RemoteProtocol.socketPath}'
      '?${RemoteProtocol.tokenParam}=${Uri.encodeComponent(token)}',
    ).replace(scheme: 'ws');

    try {
      final socket = await WebSocket.connect(
        url.toString(),
      ).timeout(_httpTimeout);
      if (_disposed || !_wantConnection) {
        unawaited(socket.close());
        return;
      }
      _socket = socket;
      _reconnectAttempts = 0;
      _emit(
        RemoteConnection(
          status: RemoteConnectionStatus.connected,
          device: device,
          playback: _connection.playback,
        ),
      );
      unawaited(
        _logger.info('remote.client.connected', attrs: {'host': device.id}),
      );
      _socketSub = socket.listen(
        _onFrame,
        onDone: () => _onDropped(device),
        onError: (Object e, StackTrace st) {
          unawaited(
            _logger.warn('remote.client.socket_error', error: e, stack: st),
          );
          _onDropped(device);
        },
        cancelOnError: true,
      );
    } catch (e, st) {
      unawaited(
        _logger.warn('remote.client.connect_failed', error: e, stack: st),
      );
      await _classifyFailure(device, token);
    }
  }

  /// Decides whether a failed upgrade means "bad token" or "host
  /// unreachable".
  ///
  /// `WebSocket.connect` collapses every non-101 response into the same
  /// exception, so the status code is unavailable. Probing the
  /// unauthenticated `/info` endpoint separates the two cases: if the
  /// host answers there, it is alive and it was the token it refused.
  Future<void> _classifyFailure(RemoteDevice device, String? token) async {
    final reachable = await _probeInfo(device.baseUrl);
    if (reachable && token != null) {
      await _pairing.deleteTokenForHost(device.id);
      _emit(
        RemoteConnection(
          status: RemoteConnectionStatus.pairingRequired,
          device: device,
        ),
      );
      return;
    }
    _emit(
      RemoteConnection(
        status: RemoteConnectionStatus.failed,
        device: device,
        errorMessage: reachable
            ? 'Connexion refusée par ${device.name}.'
            : '${device.name} est injoignable sur le réseau.',
      ),
    );
  }

  Future<bool> _probeInfo(String baseUrl) async {
    final client = HttpClient()..connectionTimeout = _httpTimeout;
    try {
      final request = await client
          .getUrl(Uri.parse('$baseUrl${RemoteProtocol.infoPath}'))
          .timeout(_httpTimeout);
      final response = await request.close().timeout(_httpTimeout);
      await response.drain<void>();
      return response.statusCode == HttpStatus.ok;
    } catch (_) {
      return false;
    } finally {
      client.close(force: true);
    }
  }

  void _onFrame(Object? frame) {
    if (frame is! String) return;
    final message = RemoteProtocol.decode(frame);
    switch (message) {
      case RemoteStateMessage(:final state):
        _emit(_connection.copyWith(playback: state, clearError: true));
      case RemoteErrorMessage(:final message):
        _emit(_connection.copyWith(errorMessage: message));
      case RemoteQueryResultMessage(:final result):
        _pendingQueries.remove(result.queryId)?.complete(result);
      case _:
        break;
    }
  }

  void _onDropped(RemoteDevice device) {
    _socketSub = null;
    _socket = null;
    _failPendingQueries('disconnected', 'Connexion perdue.');
    if (_disposed || !_wantConnection) return;
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      _emit(
        _connection.copyWith(
          status: RemoteConnectionStatus.failed,
          errorMessage: 'Connexion perdue avec ${device.name}.',
        ),
      );
      return;
    }
    _reconnectAttempts++;
    _emit(_connection.copyWith(status: RemoteConnectionStatus.connecting));
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(_reconnectDelay, () {
      if (!_wantConnection || _disposed) return;
      unawaited(_openSocket(device));
    });
  }

  @override
  Future<bool> pair(RemoteDevice device, String code) async {
    final client = HttpClient()..connectionTimeout = _httpTimeout;
    try {
      final request = await client
          .postUrl(Uri.parse('${device.baseUrl}${RemoteProtocol.pairPath}'))
          .timeout(_httpTimeout);
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode({'code': code}));
      final response = await request.close().timeout(_httpTimeout);
      final body = await utf8.decoder.bind(response).join();
      if (response.statusCode != HttpStatus.ok) {
        unawaited(
          _logger.warn(
            'remote.client.pair_rejected',
            attrs: {'status': response.statusCode},
          ),
        );
        return false;
      }
      final decoded = jsonDecode(body);
      final token = decoded is Map ? decoded['token'] : null;
      if (token is! String || token.isEmpty) return false;
      await _pairing.saveTokenForHost(
        hostDeviceId: device.id,
        token: token,
      );
      unawaited(_logger.info('remote.client.paired', attrs: {'host': device.id}));
      await connect(device);
      return true;
    } catch (e, st) {
      unawaited(_logger.warn('remote.client.pair_failed', error: e, stack: st));
      return false;
    } finally {
      client.close(force: true);
    }
  }

  @override
  Future<void> send(RemoteCommand command) async {
    final socket = _socket;
    if (socket == null || socket.readyState != WebSocket.open) return;
    try {
      socket.add(RemoteProtocol.encodeCommand(command));
    } catch (e, st) {
      unawaited(_logger.warn('remote.client.send_failed', error: e, stack: st));
    }
  }

  @override
  Future<Map<String, Object?>> query(
    String kind, {
    Map<String, Object?> params = const {},
  }) async {
    final socket = _socket;
    if (socket == null || socket.readyState != WebSocket.open) {
      throw const RemoteQueryException('disconnected', 'Appareil non connecté.');
    }
    _queryCounter++;
    final queryId = 'q$_queryCounter';
    final completer = Completer<RemoteQueryResult>();
    _pendingQueries[queryId] = completer;
    try {
      socket.add(
        RemoteProtocol.encodeQuery(
          RemoteQuery(queryId: queryId, kind: kind, params: params),
        ),
      );
      final result = await completer.future.timeout(_queryTimeout);
      final data = result.data;
      if (data == null) {
        throw RemoteQueryException(
          result.errorCode ?? 'query_failed',
          result.errorMessage ?? 'La requête a échoué.',
        );
      }
      return data;
    } on TimeoutException {
      throw const RemoteQueryException(
        'timeout',
        "L'appareil n'a pas répondu.",
      );
    } finally {
      _pendingQueries.remove(queryId);
    }
  }

  @override
  Future<void> disconnect() async {
    _wantConnection = false;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    await _closeSocket();
    _emit(RemoteConnection.disconnected);
  }

  @override
  Future<void> forget(String deviceId) async {
    await _pairing.deleteTokenForHost(deviceId);
    if (_connection.device?.id == deviceId) await disconnect();
  }

  @override
  void clearError() {
    if (_connection.errorMessage == null) return;
    _emit(_connection.copyWith(clearError: true));
  }

  Future<void> _closeSocket() async {
    final sub = _socketSub;
    final socket = _socket;
    _socketSub = null;
    _socket = null;
    await sub?.cancel();
    try {
      await socket?.close(WebSocketStatus.normalClosure);
    } catch (_) {
      // Already gone.
    }
  }

  void _emit(RemoteConnection connection) {
    _connection = connection;
    if (_disposed || _controller.isClosed) return;
    _controller.add(connection);
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _wantConnection = false;
    _reconnectTimer?.cancel();
    _failPendingQueries('disposed', 'Service arrêté.');
    await _closeSocket();
    await _controller.close();
  }

  /// Settles every in-flight query with a failure, so an awaiting screen
  /// gets a retry rather than hanging on the timeout.
  void _failPendingQueries(String code, String message) {
    if (_pendingQueries.isEmpty) return;
    final pending = _pendingQueries.values.toList();
    _pendingQueries.clear();
    for (final completer in pending) {
      if (!completer.isCompleted) {
        completer.completeError(RemoteQueryException(code, message));
      }
    }
  }
}
