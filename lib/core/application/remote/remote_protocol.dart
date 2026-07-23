import 'dart:convert';

import 'package:kidflix/core/application/remote/remote_query.dart';
import 'package:kidflix/core/domain/model/remote_command.dart';
import 'package:kidflix/core/domain/model/remote_playback_state.dart';

/// Wire contract shared by the host (server) and the remote (client).
///
/// Both sides of the link are the *same app build* in the common case,
/// but not necessarily the same *version* — a phone updated from the
/// store can drive a TV-side install that is one release behind. So the
/// framing is versioned and tolerant: unknown message kinds and unknown
/// command verbs are dropped, never fatal.
abstract final class RemoteProtocol {
  /// Bumped only on a breaking change to the framing or to the meaning of
  /// an existing field. Adding an optional field or a new command verb is
  /// backwards compatible and must NOT bump it.
  static const int version = 1;

  /// mDNS service type. 15 chars max for the first label (RFC 6335).
  static const String serviceType = '_kidflix._tcp';

  /// Default TCP port. The host falls back to an ephemeral port when this
  /// one is taken, and advertises whatever it actually got — discovery
  /// never assumes the default.
  static const int defaultPort = 47017;

  /// TXT record keys carried by the mDNS advertisement.
  static const String txtDeviceId = 'id';
  static const String txtDeviceName = 'name';
  static const String txtPlatform = 'plat';
  static const String txtVersion = 'v';

  /// HTTP paths.
  static const String pairPath = '/pair';
  static const String infoPath = '/info';
  static const String socketPath = '/ws';

  /// Query parameter carrying the bearer token on the WebSocket upgrade.
  ///
  /// A header would be cleaner, but `WebSocket.connect` on some platforms
  /// does not let us set arbitrary headers reliably, and the token never
  /// leaves the LAN.
  static const String tokenParam = 'token';

  static const String kindCommand = 'command';
  static const String kindState = 'state';
  static const String kindError = 'error';
  static const String kindQuery = 'query';
  static const String kindQueryResult = 'queryResult';

  /// Frames a remote→host data request.
  static String encodeQuery(RemoteQuery query) =>
      jsonEncode({'kind': kindQuery, 'payload': query.toJson()});

  /// Frames the host's answer.
  static String encodeQueryResult(RemoteQueryResult result) =>
      jsonEncode({'kind': kindQueryResult, 'payload': result.toJson()});

  /// Frames a remote→host command.
  static String encodeCommand(RemoteCommand command) =>
      jsonEncode({'kind': kindCommand, 'payload': command.toJson()});

  /// Frames a host→remote state push.
  static String encodeState(RemotePlaybackState state) =>
      jsonEncode({'kind': kindState, 'payload': state.toJson()});

  /// Frames a host→remote error. [code] is a stable machine token
  /// (`not_found`, `forbidden`, `unavailable`); [message] is French prose
  /// shown as-is to the user.
  static String encodeError(String code, String message) => jsonEncode({
    'kind': kindError,
    'payload': {'code': code, 'message': message},
  });

  /// Parses any framed message. Returns null on malformed JSON or an
  /// unknown kind — callers ignore those frames.
  ///
  /// Total by contract: this runs inside a socket listener on both sides,
  /// so anything it throws would surface as `onError` and tear down a
  /// working link because of one bad frame. The individual decoders are
  /// written to be total; the catch-all here is the backstop.
  static RemoteMessage? decode(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final json = Map<String, Object?>.from(decoded);
      final payload = json['payload'];
      if (payload is! Map) return null;
      final map = Map<String, Object?>.from(payload);
      return switch (json['kind']) {
        kindCommand => switch (RemoteCommand.fromJson(map)) {
          final command? => RemoteCommandMessage(command),
          _ => null,
        },
        kindState => RemoteStateMessage(RemotePlaybackState.fromJson(map)),
        kindQuery => switch (RemoteQuery.fromJson(map)) {
          final query? => RemoteQueryMessage(query),
          _ => null,
        },
        kindQueryResult => switch (RemoteQueryResult.fromJson(map)) {
          final result? => RemoteQueryResultMessage(result),
          _ => null,
        },
        kindError => RemoteErrorMessage(
          code: map['code'] is String ? map['code']! as String : 'unknown',
          message: map['message'] is String ? map['message']! as String : '',
        ),
        _ => null,
      };
    } catch (_) {
      return null;
    }
  }
}

/// A decoded frame.
sealed class RemoteMessage {
  const RemoteMessage();
}

class RemoteCommandMessage extends RemoteMessage {
  final RemoteCommand command;
  const RemoteCommandMessage(this.command);
}

class RemoteStateMessage extends RemoteMessage {
  final RemotePlaybackState state;
  const RemoteStateMessage(this.state);
}

class RemoteErrorMessage extends RemoteMessage {
  final String code;
  final String message;
  const RemoteErrorMessage({required this.code, required this.message});
}

class RemoteQueryMessage extends RemoteMessage {
  final RemoteQuery query;
  const RemoteQueryMessage(this.query);
}

class RemoteQueryResultMessage extends RemoteMessage {
  final RemoteQueryResult result;
  const RemoteQueryResultMessage(this.result);
}
