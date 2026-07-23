import 'package:flutter_test/flutter_test.dart';
import 'package:kidflix/core/application/remote/remote_protocol.dart';
import 'package:kidflix/core/application/remote/remote_query.dart';

void main() {
  group('RemoteQuery round-trip', () {
    test('a home-rows query survives encode → decode', () {
      const query = RemoteQuery(
        queryId: 'q1',
        kind: RemoteQuery.kindHomeRows,
      );

      final message =
          RemoteProtocol.decode(RemoteProtocol.encodeQuery(query))
              as RemoteQueryMessage;

      expect(message.query.queryId, equals('q1'));
      expect(message.query.kind, equals(RemoteQuery.kindHomeRows));
    });

    test('a media-detail query carries its params', () {
      const query = RemoteQuery(
        queryId: 'q2',
        kind: RemoteQuery.kindMediaDetail,
        params: {'mediaId': 'movie-9', 'isSeries': false},
      );

      final message =
          RemoteProtocol.decode(RemoteProtocol.encodeQuery(query))
              as RemoteQueryMessage;

      expect(message.query.params['mediaId'], equals('movie-9'));
      expect(message.query.params['isSeries'], isFalse);
    });

    test('a query missing its id decodes to null', () {
      expect(RemoteQuery.fromJson({'kind': 'homeRows'}), isNull);
    });
  });

  group('RemoteQueryResult round-trip', () {
    test('a success carries its data back', () {
      final result = RemoteQueryResult.success('q1', {
        'rows': [
          {'label': 'Récents', 'type': 'recentlyAdded', 'items': []},
        ],
      });

      final message =
          RemoteProtocol.decode(RemoteProtocol.encodeQueryResult(result))
              as RemoteQueryResultMessage;

      expect(message.result.queryId, equals('q1'));
      expect(message.result.isSuccess, isTrue);
      expect((message.result.data!['rows'] as List), hasLength(1));
    });

    test('a failure carries a code and message, no data', () {
      final result = RemoteQueryResult.failure(
        'q3',
        code: 'query_failed',
        message: 'Indisponible.',
      );

      final message =
          RemoteProtocol.decode(RemoteProtocol.encodeQueryResult(result))
              as RemoteQueryResultMessage;

      expect(message.result.isSuccess, isFalse);
      expect(message.result.errorCode, equals('query_failed'));
      expect(message.result.errorMessage, equals('Indisponible.'));
      expect(message.result.data, isNull);
    });

    test('a result missing its id decodes to null', () {
      expect(RemoteQueryResult.fromJson({'data': {}}), isNull);
    });
  });

  test('a malformed query frame is dropped, not fatal', () {
    // These arrive on the same socket that carries commands and state;
    // one bad frame must not tear the link down.
    expect(
      RemoteProtocol.decode('{"kind":"query","payload":{"queryId":42}}'),
      isNull,
    );
  });
}
