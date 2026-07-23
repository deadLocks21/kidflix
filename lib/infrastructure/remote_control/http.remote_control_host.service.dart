import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:kidflix/core/application/remote/remote_protocol.dart';
import 'package:kidflix/core/application/remote/remote_query.dart';
import 'package:kidflix/core/application/services/logger_application.service.dart';
import 'package:kidflix/core/domain/model/remote_command.dart';
import 'package:kidflix/core/domain/model/remote_playback_state.dart';
import 'package:kidflix/core/domain/services/remote_control_host.service.dart';
import 'package:kidflix/core/domain/services/remote_discovery.service.dart';
import 'package:kidflix/core/domain/services/remote_pairing.repository.dart';
import 'package:kidflix/infrastructure/remote_control/lan_address.dart';

/// Minimum gap between two pushes that differ only by playback position.
///
/// mpv reports position at roughly 4 Hz. Forwarding every tick would send
/// the full snapshot — track lists included — four times a second to each
/// remote for no visible benefit; one push per second keeps a seek bar
/// perfectly smooth. Any *other* change bypasses this and goes out at
/// once, so play/pause never feels laggy.
const Duration _positionPushInterval = Duration(milliseconds: 1000);

/// Wrong codes tolerated before the pairing code is rotated.
///
/// Six digits is a million combinations; over a LAN an attacker could
/// walk that in minutes. Rotating after a handful of misses means a
/// guessing run invalidates the very code it is hunting for.
const int _maxPairingAttempts = 5;

/// `dart:io` implementation of the control server.
///
/// One `HttpServer` serving three things: an unauthenticated `/info`
/// probe (so a hand-typed IP can be identified before pairing), a
/// `/pair` code exchange, and the `/ws` WebSocket carrying commands up
/// and state down.
class HttpRemoteControlHostService implements RemoteControlHostService {
  /// Both identity fields are resolved lazily, at `start()` / request
  /// time. Holding them as plain values forced the provider to `watch`
  /// their sources, which rebuilt — and tore down — a running server
  /// whenever either changed.
  final String Function() resolveDeviceId;

  final String Function() resolveDeviceName;

  final String platformName;
  final RemotePairingRepository _pairing;
  final RemoteDiscoveryService _discovery;
  final LoggerApplicationService _logger;
  final int preferredPort;

  HttpRemoteControlHostService({
    required this.resolveDeviceId,
    required this.resolveDeviceName,
    required this.platformName,
    required RemotePairingRepository pairing,
    required RemoteDiscoveryService discovery,
    required LoggerApplicationService logger,
    this.preferredPort = RemoteProtocol.defaultPort,
  }) : _pairing = pairing,
       _discovery = discovery,
       _logger = logger;

  final _random = Random.secure();
  final _sockets = <WebSocket>{};

  /// Which socket asked each in-flight query, so [answerQuery] replies
  /// only to the asker instead of broadcasting one remote's catalogue to
  /// every connected remote.
  final _queryOrigins = <String, WebSocket>{};
  final _statusController = StreamController<RemoteHostStatus>.broadcast();
  final _commandController = StreamController<RemoteCommand>.broadcast();
  final _queryController = StreamController<RemoteQuery>.broadcast();

  HttpServer? _server;
  StreamSubscription<HttpRequest>? _requestSub;
  Set<String> _issuedTokens = {};
  int _failedPairingAttempts = 0;
  RemoteHostStatus _status = RemoteHostStatus.stopped;

  RemotePlaybackState _lastState = RemotePlaybackState.idle;
  String? _lastSignature;
  DateTime? _lastPushAt;
  bool _disposed = false;

  @override
  RemoteHostStatus get status => _status;

  @override
  Stream<RemoteHostStatus> get statusStream async* {
    yield _status;
    yield* _statusController.stream;
  }

  @override
  Stream<RemoteCommand> get commands => _commandController.stream;

  @override
  Stream<RemoteQuery> get queries => _queryController.stream;

  @override
  void answerQuery(RemoteQueryResult result) {
    // The asking socket may have gone before the answer was ready (a
    // remote closing the sheet mid-fetch) — drop the answer rather than
    // spraying it at everyone.
    final socket = _queryOrigins.remove(result.queryId);
    if (socket == null) return;
    try {
      socket.add(RemoteProtocol.encodeQueryResult(result));
    } catch (_) {
      // Socket died between removal and write; nothing to do.
    }
  }

  @override
  Future<RemoteHostStatus> start() async {
    if (_disposed) return _status;
    // Idempotent: a second start must not rotate the code out from under
    // a user who is mid-way through typing it on their phone.
    if (_server != null) return _status;

    _issuedTokens = await _pairing.loadIssuedTokens();
    _failedPairingAttempts = 0;

    if (resolveDeviceId().isEmpty) {
      // Refuse rather than advertise an unusable identity: with an empty
      // id every remote silently drops this device from its list, and a
      // manual pairing would store its token under a key shared with
      // every other id-less host. Failing loudly beats a server that is
      // up but invisible.
      unawaited(_logger.error('remote.host.missing_device_id'));
      _emit(
        RemoteHostStatus.stopped.copyWith(
          errorMessage: "Identifiant d'appareil indisponible.",
        ),
      );
      return _status;
    }

    final HttpServer server;
    try {
      server = await _bind();
    } on SocketException catch (e, st) {
      unawaited(
        _logger.error(
          'remote.host.bind_failed',
          attrs: {'port': preferredPort},
          error: e,
          stack: st,
        ),
      );
      _emit(
        RemoteHostStatus.stopped.copyWith(
          errorMessage: "Impossible d'ouvrir le port réseau.",
        ),
      );
      return _status;
    }
    _server = server;
    _requestSub = server.listen(
      _handleRequest,
      onError: (Object e, StackTrace st) => unawaited(
        _logger.warn('remote.host.request_error', error: e, stack: st),
      ),
    );

    final addresses = await localNetworkAddresses();
    _emit(
      RemoteHostStatus(
        running: true,
        port: server.port,
        addresses: addresses,
        pairingCode: _generatePairingCode(),
        connectedRemotes: 0,
      ),
    );

    try {
      await _discovery.advertise(
        name: resolveDeviceName(),
        port: server.port,
        attributes: {
          RemoteProtocol.txtDeviceId: resolveDeviceId(),
          RemoteProtocol.txtDeviceName: resolveDeviceName(),
          RemoteProtocol.txtPlatform: platformName,
          RemoteProtocol.txtVersion: '${RemoteProtocol.version}',
        },
      );
    } catch (e, st) {
      // The socket is up and manual pairing by IP still works — degrade
      // to "discoverable only by hand" instead of failing the start.
      unawaited(
        _logger.warn('remote.host.advertise_failed', error: e, stack: st),
      );
      _emit(
        _status.copyWith(
          errorMessage:
              'Découverte automatique indisponible — utilise l\'adresse IP.',
        ),
      );
    }

    unawaited(
      _logger.info(
        'remote.host.started',
        attrs: {'port': server.port, 'addresses': addresses.join(',')},
      ),
    );
    return _status;
  }

  /// Binds the preferred port, falling back to an ephemeral one.
  ///
  /// A stale socket from a previous run in TIME_WAIT, or a second install
  /// on the same machine, must not make the feature unavailable — the
  /// actual port is advertised over mDNS anyway.
  Future<HttpServer> _bind() async {
    try {
      return await HttpServer.bind(InternetAddress.anyIPv4, preferredPort);
    } on SocketException {
      return HttpServer.bind(InternetAddress.anyIPv4, 0);
    }
  }

  @override
  Future<void> stop() async {
    final server = _server;
    _server = null;
    await _requestSub?.cancel();
    _requestSub = null;
    for (final socket in _sockets.toList()) {
      unawaited(socket.close(WebSocketStatus.goingAway));
    }
    _sockets.clear();
    try {
      await _discovery.stopAdvertising();
    } catch (_) {
      // Best effort — we are shutting down either way.
    }
    await server?.close(force: true);
    _lastSignature = null;
    _lastPushAt = null;
    _emit(RemoteHostStatus.stopped);
    unawaited(_logger.info('remote.host.stopped'));
  }

  @override
  void publishState(RemotePlaybackState state) {
    _lastState = state;
    if (_sockets.isEmpty) return;
    final signature = _signatureOf(state);
    final now = DateTime.now();
    final positionOnlyChange = signature == _lastSignature;
    if (positionOnlyChange && _lastPushAt != null) {
      if (now.difference(_lastPushAt!) < _positionPushInterval) return;
    }
    _lastSignature = signature;
    _lastPushAt = now;
    _broadcast(RemoteProtocol.encodeState(state));
  }

  /// Everything about the state *except* the playback position, so a
  /// pure position tick can be told apart from a real change.
  String _signatureOf(RemotePlaybackState state) {
    final json = state.toJson()..remove('positionMs');
    return jsonEncode(json);
  }

  @override
  void reportError(String code, String message) {
    _broadcast(RemoteProtocol.encodeError(code, message));
  }

  void _broadcast(String frame) {
    for (final socket in _sockets.toList()) {
      try {
        socket.add(frame);
      } catch (_) {
        // Socket died between the liveness check and the write; the done
        // handler removes it.
      }
    }
  }

  Future<void> _handleRequest(HttpRequest request) async {
    final remote = request.connectionInfo?.remoteAddress;
    if (!isPrivateAddress(remote)) {
      unawaited(
        _logger.warn(
          'remote.host.rejected_public_client',
          attrs: {'remote': remote?.address},
        ),
      );
      await _reject(request, HttpStatus.forbidden, 'forbidden');
      return;
    }
    try {
      switch (request.uri.path) {
        case RemoteProtocol.infoPath:
          await _handleInfo(request);
        case RemoteProtocol.pairPath:
          await _handlePair(request);
        case RemoteProtocol.socketPath:
          await _handleSocket(request);
        default:
          await _reject(request, HttpStatus.notFound, 'not_found');
      }
    } catch (e, st) {
      unawaited(_logger.warn('remote.host.handler_failed', error: e, stack: st));
      try {
        await _reject(request, HttpStatus.internalServerError, 'server_error');
      } catch (_) {
        // Response already committed — nothing left to say.
      }
    }
  }

  /// Unauthenticated identity probe, so a remote pairing by hand-typed IP
  /// can show *which* device it is about to pair with. Deliberately
  /// exposes nothing beyond what the mDNS TXT record already broadcasts.
  Future<void> _handleInfo(HttpRequest request) async {
    request.response
      ..statusCode = HttpStatus.ok
      ..headers.contentType = ContentType.json
      ..write(
        jsonEncode({
          'id': resolveDeviceId(),
          'name': resolveDeviceName(),
          'platform': platformName,
          'version': RemoteProtocol.version,
        }),
      );
    await request.response.close();
  }

  Future<void> _handlePair(HttpRequest request) async {
    if (request.method != 'POST') {
      await _reject(request, HttpStatus.methodNotAllowed, 'method_not_allowed');
      return;
    }
    final body = await utf8.decoder.bind(request).join();
    final Object? decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException {
      await _reject(request, HttpStatus.badRequest, 'bad_request');
      return;
    }
    final code = decoded is Map ? decoded['code'] : null;
    if (code is! String || code != _status.pairingCode) {
      _failedPairingAttempts++;
      unawaited(
        _logger.warn(
          'remote.host.pairing_rejected',
          attrs: {'attempts': _failedPairingAttempts},
        ),
      );
      if (_failedPairingAttempts >= _maxPairingAttempts) {
        _failedPairingAttempts = 0;
        _emit(_status.copyWith(pairingCode: _generatePairingCode()));
        unawaited(_logger.warn('remote.host.pairing_code_rotated'));
      }
      await _reject(request, HttpStatus.forbidden, 'invalid_code');
      return;
    }

    _failedPairingAttempts = 0;
    final token = _generateToken();
    _issuedTokens = {..._issuedTokens, token};
    await _pairing.addIssuedToken(token);
    unawaited(_logger.info('remote.host.paired'));

    request.response
      ..statusCode = HttpStatus.ok
      ..headers.contentType = ContentType.json
      ..write(jsonEncode({'token': token, 'name': resolveDeviceName()}));
    await request.response.close();
  }

  Future<void> _handleSocket(HttpRequest request) async {
    final token = request.uri.queryParameters[RemoteProtocol.tokenParam];
    if (token == null || !_issuedTokens.contains(token)) {
      await _reject(request, HttpStatus.unauthorized, 'unauthorized');
      return;
    }
    if (!WebSocketTransformer.isUpgradeRequest(request)) {
      await _reject(request, HttpStatus.badRequest, 'not_an_upgrade');
      return;
    }
    final socket = await WebSocketTransformer.upgrade(request);
    _sockets.add(socket);
    _emit(_status.copyWith(connectedRemotes: _sockets.length));
    unawaited(
      _logger.info(
        'remote.host.client_connected',
        attrs: {'clients': _sockets.length},
      ),
    );

    // Seed the fresh remote with the current state so it renders the
    // right thing immediately instead of waiting for the next change.
    socket.add(RemoteProtocol.encodeState(_lastState));
    // A push to the seeded socket must not be suppressed as a duplicate
    // for the other remotes, so leave the coalescing marks untouched.

    socket.listen(
      (Object? frame) {
        if (frame is! String) return;
        switch (RemoteProtocol.decode(frame)) {
          case RemoteCommandMessage(:final command):
            _commandController.add(command);
          case RemoteQueryMessage(:final query):
            _queryOrigins[query.queryId] = socket;
            _queryController.add(query);
          case _:
            break;
        }
      },
      onDone: () => _removeSocket(socket),
      onError: (Object e, StackTrace st) {
        unawaited(_logger.warn('remote.host.socket_error', error: e, stack: st));
        _removeSocket(socket);
      },
      cancelOnError: true,
    );
  }

  void _removeSocket(WebSocket socket) {
    if (!_sockets.remove(socket)) return;
    // Forget any queries this socket had outstanding — their answers now
    // have nowhere to go.
    _queryOrigins.removeWhere((_, origin) => identical(origin, socket));
    if (_disposed) return;
    _emit(_status.copyWith(connectedRemotes: _sockets.length));
    unawaited(
      _logger.info(
        'remote.host.client_disconnected',
        attrs: {'clients': _sockets.length},
      ),
    );
  }

  Future<void> _reject(HttpRequest request, int statusCode, String code) async {
    request.response
      ..statusCode = statusCode
      ..headers.contentType = ContentType.json
      ..write(jsonEncode({'error': code}));
    await request.response.close();
  }

  void _emit(RemoteHostStatus status) {
    _status = status;
    if (_disposed || _statusController.isClosed) return;
    _statusController.add(status);
  }

  String _generatePairingCode() =>
      List.generate(6, (_) => _random.nextInt(10)).join();

  String _generateToken() {
    final bytes = List.generate(32, (_) => _random.nextInt(256));
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await stop();
    await _statusController.close();
    await _commandController.close();
    await _queryController.close();
  }
}
