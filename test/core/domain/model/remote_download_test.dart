import 'package:flutter_test/flutter_test.dart';
import 'package:kidflix/core/application/remote/remote_protocol.dart';
import 'package:kidflix/core/domain/model/remote_download.dart';
import 'package:kidflix/core/domain/model/remote_playback_state.dart';

void main() {
  group('RemoteDownloadSnapshot', () {
    test('survives a full frame round-trip', () {
      const state = RemotePlaybackState(
        download: RemoteDownloadSnapshot(
          status: RemoteDownloadStatus.downloading,
          bytesReceived: 512 * 1024 * 1024,
          bytesTotal: 1024 * 1024 * 1024,
          errorMessage: null,
        ),
      );

      final decoded =
          (RemoteProtocol.decode(RemoteProtocol.encodeState(state))
                  as RemoteStateMessage)
              .state
              .download;

      expect(decoded.status, equals(RemoteDownloadStatus.downloading));
      expect(decoded.bytesReceived, equals(512 * 1024 * 1024));
      expect(decoded.bytesTotal, equals(1024 * 1024 * 1024));
      expect(decoded.fraction, closeTo(0.5, 0.001));
    });

    test('a failure carries its message across', () {
      const state = RemotePlaybackState(
        download: RemoteDownloadSnapshot(
          status: RemoteDownloadStatus.failed,
          bytesReceived: 1024,
          errorMessage: 'kdrive_upstream_error',
        ),
      );

      final decoded =
          (RemoteProtocol.decode(RemoteProtocol.encodeState(state))
                  as RemoteStateMessage)
              .state
              .download;

      expect(decoded.errorMessage, equals('kdrive_upstream_error'));
      expect(decoded.isFailed, isTrue);
      expect(decoded.canRetry, isTrue);
    });

    test('an interrupted download can be retried even while complete-ish', () {
      const snapshot = RemoteDownloadSnapshot(
        status: RemoteDownloadStatus.downloading,
        interrupted: true,
      );

      // It died mid-playback: not a "failed" status, but still the one
      // case where a retry is the right offer.
      expect(snapshot.isFailed, isFalse);
      expect(snapshot.canRetry, isTrue);
    });

    group('fraction', () {
      test('is null without a total, so no percentage is invented', () {
        // Chunked endpoints send no Content-Length.
        const snapshot = RemoteDownloadSnapshot(
          status: RemoteDownloadStatus.downloading,
          bytesReceived: 5000,
        );

        expect(snapshot.fraction, isNull);
      });

      test('is null once complete — nothing left to grey out', () {
        const snapshot = RemoteDownloadSnapshot(
          status: RemoteDownloadStatus.complete,
          bytesReceived: 100,
          bytesTotal: 100,
        );

        expect(snapshot.fraction, isNull);
      });

      test('clamps to 1 when more bytes land than announced', () {
        const snapshot = RemoteDownloadSnapshot(
          status: RemoteDownloadStatus.downloading,
          bytesReceived: 120,
          bytesTotal: 100,
        );

        expect(snapshot.fraction, equals(1.0));
      });
    });

    test('downloadedFraction on the state delegates to the snapshot', () {
      // Derived, not carried: the two can never disagree on the wire.
      const state = RemotePlaybackState(
        download: RemoteDownloadSnapshot(
          status: RemoteDownloadStatus.downloading,
          bytesReceived: 25,
          bytesTotal: 100,
        ),
      );

      expect(state.downloadedFraction, closeTo(0.25, 0.001));
      expect(RemoteProtocol.encodeState(state), isNot(contains('downloadedFraction')));
    });

    test('a frame from a host predating this decodes to "none"', () {
      final state = RemotePlaybackState.fromJson({'status': 'playing'});

      expect(state.download.status, equals(RemoteDownloadStatus.none));
      expect(state.downloadedFraction, isNull);
    });

    test('an unknown status falls back to none', () {
      final snapshot = RemoteDownloadSnapshot.fromJson({'status': 'paused?'});

      expect(snapshot.status, equals(RemoteDownloadStatus.none));
    });
  });

  group('formatting helpers feeding the card', () {
    test('isRunning covers both in-flight states', () {
      for (final status in RemoteDownloadStatus.values) {
        final running = RemoteDownloadSnapshot(status: status).isRunning;
        expect(
          running,
          equals(
            status == RemoteDownloadStatus.downloading ||
                status == RemoteDownloadStatus.readyToPlay,
          ),
          reason: 'for $status',
        );
      }
    });
  });
}
