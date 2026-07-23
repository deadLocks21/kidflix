import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kidflix/core/application/remote/remote_protocol.dart';
import 'package:kidflix/core/application/remote/remote_query.dart';
import 'package:kidflix/core/application/services/logger_application.service.dart';
import 'package:kidflix/core/domain/model/remote_command.dart';
import 'package:kidflix/core/domain/model/remote_playback_state.dart';
import 'package:kidflix/core/domain/services/remote_pairing.repository.dart';
import 'package:kidflix/infrastructure/logger/in_memory.logger.service.dart';
import 'package:kidflix/infrastructure/remote_control/http.remote_control_host.service.dart';
import 'package:kidflix/infrastructure/remote_control/noop.remote_discovery.service.dart';

/// In-memory pairing store. Mirrors the `InMemory*Repository` pattern.
class _FakePairing implements RemotePairingRepository {
  final Map<String, String> hostTokens = {};
  Set<String> issued = {};

  @override
  Future<String?> findTokenForHost(String hostDeviceId) async =>
      hostTokens[hostDeviceId];

  @override
  Future<void> saveTokenForHost({
    required String hostDeviceId,
    required String token,
  }) async {
    hostTokens[hostDeviceId] = token;
  }

  @override
  Future<void> deleteTokenForHost(String hostDeviceId) async {
    hostTokens.remove(hostDeviceId);
  }

  @override
  Future<Set<String>> loadIssuedTokens() async => issued;

  @override
  Future<void> addIssuedToken(String token) async {
    issued = {...issued, token};
  }

  @override
  Future<void> clearIssuedTokens() async {
    issued = {};
  }
}

void main() {
  late HttpRemoteControlHostService host;
  late _FakePairing pairing;
  late String deviceId;

  setUp(() {
    pairing = _FakePairing();
    deviceId = 'host-1';
    host = HttpRemoteControlHostService(
      resolveDeviceId: () => deviceId,
      resolveDeviceName: () => 'Salon',
      platformName: 'macos',
      pairing: pairing,
      discovery: const NoopRemoteDiscoveryService(),
      logger: LoggerApplicationService(InMemoryLoggerService()),
      // Ephemeral: a fixed port would make the suite flaky on a machine
      // already running the app.
      preferredPort: 0,
    );
  });

  tearDown(() => host.dispose());

  String base() => 'http://127.0.0.1:${host.status.port}';

  Future<HttpClientResponse> post(String path, Object body) async {
    final client = HttpClient();
    final request = await client.postUrl(Uri.parse('${base()}$path'));
    request.headers.contentType = ContentType.json;
    request.write(jsonEncode(body));
    return request.close();
  }

  test('start binds a port and produces a 6-digit pairing code', () async {
    final status = await host.start();

    expect(status.running, isTrue);
    expect(status.port, isNotNull);
    expect(status.port, greaterThan(0));
    expect(status.pairingCode, matches(RegExp(r'^\d{6}$')));
  });

  test('start refuses to advertise without a device id', () async {
    // The id keys the pairing token on the remote side and filters the
    // advertisement in discovery. Coming up with an empty one produced a
    // server that was running yet invisible to every remote — worse than
    // not starting at all, because nothing said so.
    deviceId = '';

    final status = await host.start();

    expect(status.running, isFalse);
    expect(status.errorMessage, isNotNull);
    // Nothing bound, so a retry after the id resolves is free.
    expect(status.port, isNull);
  });

  test('the advertised identity is read at request time, not construction', () {
    // Held as a callback so the provider never has to `watch` the id —
    // watching rebuilt the provider and tore down the running server.
    deviceId = 'renamed-later';

    expect(host.resolveDeviceId(), equals('renamed-later'));
  });

  test('start is idempotent and keeps the pairing code stable', () async {
    final first = await host.start();
    final second = await host.start();

    // A user mid-way through typing the code must not have it change
    // under them because something re-triggered a start.
    expect(second.pairingCode, equals(first.pairingCode));
    expect(second.port, equals(first.port));
  });

  test('/info answers unauthenticated with the device identity', () async {
    await host.start();

    final client = HttpClient();
    final request = await client.getUrl(
      Uri.parse('${base()}${RemoteProtocol.infoPath}'),
    );
    final response = await request.close();
    final json =
        jsonDecode(await utf8.decoder.bind(response).join())
            as Map<String, Object?>;

    expect(response.statusCode, equals(HttpStatus.ok));
    expect(json['id'], equals('host-1'));
    expect(json['name'], equals('Salon'));
    expect(json['version'], equals(RemoteProtocol.version));
  });

  test('/pair rejects a wrong code and issues a token for the right one', () async {
    final status = await host.start();

    final rejected = await post(RemoteProtocol.pairPath, {'code': '000000'});
    await rejected.drain<void>();
    expect(rejected.statusCode, equals(HttpStatus.forbidden));

    final accepted = await post(RemoteProtocol.pairPath, {
      'code': status.pairingCode,
    });
    final json =
        jsonDecode(await utf8.decoder.bind(accepted).join())
            as Map<String, Object?>;

    expect(accepted.statusCode, equals(HttpStatus.ok));
    expect(json['token'], isA<String>());
    expect(json['token'], isNotEmpty);
    // Persisted, so the token survives a restart of the host.
    expect(pairing.issued, contains(json['token']));
  });

  test('pairing code rotates after 5 failed attempts', () async {
    final status = await host.start();
    final original = status.pairingCode;

    for (var i = 0; i < 5; i++) {
      final response = await post(RemoteProtocol.pairPath, {'code': '000000'});
      await response.drain<void>();
    }

    expect(host.status.pairingCode, isNot(equals(original)));
    expect(host.status.pairingCode, matches(RegExp(r'^\d{6}$')));
  });

  test('/ws refuses an unknown token', () async {
    await host.start();

    await expectLater(
      WebSocket.connect('ws://127.0.0.1:${host.status.port}/ws?token=nope'),
      throwsA(isA<WebSocketException>()),
    );
  });

  test('a paired remote receives the current state on connect', () async {
    final status = await host.start();
    host.publishState(
      const RemotePlaybackState(
        status: RemotePlaybackStatus.playing,
        mediaId: 'movie-7',
        title: 'Le Monde de Nemo',
      ),
    );

    final socket = await _connectPaired(host, status.pairingCode, post);
    addTearDown(socket.close);

    final frame = await socket.first as String;
    final message = RemoteProtocol.decode(frame);

    // Seeded immediately rather than waiting for the next change, so a
    // remote opened mid-film is correct on frame one.
    expect(message, isA<RemoteStateMessage>());
    final state = (message as RemoteStateMessage).state;
    expect(state.mediaId, equals('movie-7'));
    expect(state.title, equals('Le Monde de Nemo'));
    expect(state.status, equals(RemotePlaybackStatus.playing));
  });

  test('commands sent by a remote surface on the commands stream', () async {
    final status = await host.start();
    final socket = await _connectPaired(host, status.pairingCode, post);
    addTearDown(socket.close);

    final received = <RemoteCommand>[];
    final subscription = host.commands.listen(received.add);
    addTearDown(subscription.cancel);

    socket.add(RemoteProtocol.encodeCommand(const RemoteTogglePlayCommand()));
    socket.add(
      RemoteProtocol.encodeCommand(const RemoteSetSubtitleTrackCommand('no')),
    );
    await _settle();

    expect(received, hasLength(2));
    expect(received.first, isA<RemoteTogglePlayCommand>());
    expect(
      (received.last as RemoteSetSubtitleTrackCommand).trackId,
      equals('no'),
    );
  });

  test('a query is answered only on the socket that asked', () async {
    final status = await host.start();
    final asker = await _connectPaired(host, status.pairingCode, post);
    final bystander = await _connectPaired(host, status.pairingCode, post);
    addTearDown(asker.close);
    addTearDown(bystander.close);

    final askerFrames = <String>[];
    final bystanderFrames = <String>[];
    asker.listen((Object? f) => askerFrames.add(f as String));
    bystander.listen((Object? f) => bystanderFrames.add(f as String));
    await _settle();
    askerFrames.clear();
    bystanderFrames.clear();

    // The application layer answers whatever it reads off `queries`.
    final subscription = host.queries.listen((query) {
      host.answerQuery(
        RemoteQueryResult.success(query.queryId, {'echo': query.kind}),
      );
    });
    addTearDown(subscription.cancel);

    asker.add(
      RemoteProtocol.encodeQuery(
        const RemoteQuery(queryId: 'q1', kind: 'homeRows'),
      ),
    );
    await _settle();

    // The answer reaches the asker…
    expect(askerFrames, hasLength(1));
    final message = RemoteProtocol.decode(askerFrames.single);
    expect(message, isA<RemoteQueryResultMessage>());
    final result = (message as RemoteQueryResultMessage).result;
    expect(result.queryId, equals('q1'));
    expect(result.data!['echo'], equals('homeRows'));
    // …and no one else, so one remote's catalogue never leaks to another.
    expect(bystanderFrames, isEmpty);
  });

  test('an answer to a vanished socket is silently dropped', () async {
    final status = await host.start();
    final asker = await _connectPaired(host, status.pairingCode, post);

    RemoteQuery? received;
    final subscription = host.queries.listen((q) => received = q);
    addTearDown(subscription.cancel);

    asker.add(
      RemoteProtocol.encodeQuery(
        const RemoteQuery(queryId: 'q9', kind: 'homeRows'),
      ),
    );
    await _settle();
    await asker.close();
    await _settle();

    // The asker is gone before the answer is ready; answering must not
    // throw or reach anyone.
    expect(received, isNotNull);
    expect(
      () => host.answerQuery(
        RemoteQueryResult.success(received!.queryId, const {}),
      ),
      returnsNormally,
    );
  });

  test('an unknown command verb is dropped without killing the link', () async {
    final status = await host.start();
    final socket = await _connectPaired(host, status.pairingCode, post);
    addTearDown(socket.close);

    final received = <RemoteCommand>[];
    final subscription = host.commands.listen(received.add);
    addTearDown(subscription.cancel);

    // A newer remote may speak verbs this build has never heard of.
    socket.add(jsonEncode({'kind': 'command', 'payload': {'type': 'teleport'}}));
    socket.add(RemoteProtocol.encodeCommand(const RemotePauseCommand()));
    await _settle();

    expect(received, hasLength(1));
    expect(received.single, isA<RemotePauseCommand>());
  });

  test('position-only changes are coalesced, other changes are not', () async {
    final status = await host.start();
    final socket = await _connectPaired(host, status.pairingCode, post);
    addTearDown(socket.close);

    final frames = <String>[];
    socket.listen((Object? frame) => frames.add(frame as String));
    await _settle();
    frames.clear(); // Drop the seed frame.

    const playing = RemotePlaybackState(
      status: RemotePlaybackStatus.playing,
      mediaId: 'm1',
    );
    host.publishState(playing);
    await _settle();
    expect(frames, hasLength(1), reason: 'first push always goes out');

    // Four position ticks in quick succession: mpv reports at ~4 Hz and
    // forwarding each one would send the whole snapshot every 250 ms.
    for (var i = 1; i <= 4; i++) {
      host.publishState(playing.copyWith(position: Duration(seconds: i)));
    }
    await _settle();
    expect(frames, hasLength(1), reason: 'position-only ticks are coalesced');

    // Pausing is a real change and must reach the remote at once.
    host.publishState(playing.copyWith(status: RemotePlaybackStatus.paused));
    await _settle();
    expect(frames, hasLength(2));
    final last = RemoteProtocol.decode(frames.last) as RemoteStateMessage;
    expect(last.state.status, equals(RemotePlaybackStatus.paused));
  });

  test('stop closes the socket and reports the host as stopped', () async {
    final status = await host.start();
    final socket = await _connectPaired(host, status.pairingCode, post);
    // A `dart:io` WebSocket only drives the protocol while subscribed —
    // without a listener the incoming close frame is never processed and
    // `done` would hang forever.
    final drained = socket.drain<void>();

    await host.stop();
    await drained;

    expect(host.status.running, isFalse);
    expect(host.status.port, isNull);
  });

  test('a token issued before a restart still works after it', () async {
    final status = await host.start();
    final response = await post(RemoteProtocol.pairPath, {
      'code': status.pairingCode,
    });
    final token =
        (jsonDecode(await utf8.decoder.bind(response).join())
            as Map<String, Object?>)['token']!;
    await host.stop();

    // The remote must not have to re-pair every time the TV reboots.
    await host.start();
    final socket = await WebSocket.connect(
      'ws://127.0.0.1:${host.status.port}/ws?token=$token',
    );
    final frames = <String>[];
    socket.listen((Object? frame) => frames.add(frame as String));
    addTearDown(socket.close);
    await _settle();

    expect(socket.readyState, equals(WebSocket.open));
    // Reaching the socket at all proves the token survived; the seed
    // frame proves the link is live rather than merely accepted.
    expect(frames, hasLength(1));
  });
}

/// Pairs with [host] and returns an open, authorised socket.
Future<WebSocket> _connectPaired(
  HttpRemoteControlHostService host,
  String code,
  Future<HttpClientResponse> Function(String, Object) post,
) async {
  final response = await post(RemoteProtocol.pairPath, {'code': code});
  final json =
      jsonDecode(await utf8.decoder.bind(response).join())
          as Map<String, Object?>;
  return WebSocket.connect(
    'ws://127.0.0.1:${host.status.port}/ws?token=${json['token']}',
  );
}

/// Lets the event loop drain pending socket I/O.
Future<void> _settle() => Future<void>.delayed(const Duration(milliseconds: 60));
