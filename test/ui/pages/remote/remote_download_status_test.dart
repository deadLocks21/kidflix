import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kidflix/core/domain/model/remote_download.dart';
import 'package:kidflix/ui/pages/remote/widgets/remote_download_status.widget.dart';

Widget _card(RemoteDownloadSnapshot download, {VoidCallback? onRetry}) =>
    MaterialApp(
      home: Scaffold(
        body: RemoteDownloadStatusCard(
          download: download,
          onRetry: onRetry ?? () {},
        ),
      ),
    );

void main() {
  group('RemoteDownloadStatusCard', () {
    testWidgets('shows percentage and sizes while downloading', (tester) async {
      await tester.pumpWidget(
        _card(
          const RemoteDownloadSnapshot(
            status: RemoteDownloadStatus.downloading,
            bytesReceived: 512 * 1024 * 1024,
            bytesTotal: 2 * 1024 * 1024 * 1024,
          ),
        ),
      );

      expect(find.text('Téléchargement en cours'), findsOneWidget);
      expect(find.text('25 % · 512 Mo / 2,0 Go'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      // Nothing is wrong, so no retry is offered.
      expect(find.text('Réessayer'), findsNothing);
    });

    testWidgets('stays indeterminate when the total is unknown', (tester) async {
      await tester.pumpWidget(
        _card(
          const RemoteDownloadSnapshot(
            status: RemoteDownloadStatus.downloading,
            bytesReceived: 30 * 1024 * 1024,
          ),
        ),
      );

      // No invented percentage.
      expect(find.text('30 Mo reçus'), findsOneWidget);
      final bar = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(bar.value, isNull);
    });

    testWidgets('surfaces the failure and offers a retry', (tester) async {
      var retried = false;
      await tester.pumpWidget(
        _card(
          const RemoteDownloadSnapshot(
            status: RemoteDownloadStatus.failed,
            errorMessage: 'kdrive_upstream_error',
          ),
          onRetry: () => retried = true,
        ),
      );

      expect(find.text('Téléchargement échoué'), findsOneWidget);
      expect(find.text('kdrive_upstream_error'), findsOneWidget);

      await tester.tap(find.text('Réessayer'));
      expect(retried, isTrue);
    });

    testWidgets('explains an interrupted download', (tester) async {
      await tester.pumpWidget(
        _card(
          const RemoteDownloadSnapshot(
            status: RemoteDownloadStatus.downloading,
            bytesReceived: 10,
            bytesTotal: 100,
            interrupted: true,
          ),
        ),
      );

      expect(find.text('Téléchargement interrompu'), findsOneWidget);
      expect(
        find.textContaining('s’arrêtera à la fin de ce qui a été téléchargé'),
        findsOneWidget,
      );
      expect(find.text('Réessayer'), findsOneWidget);
    });

    testWidgets('says nothing when there is nothing to say', (tester) async {
      // A fully local file: the transport controls already tell the whole
      // story, so the card must not add noise.
      await tester.pumpWidget(
        _card(
          const RemoteDownloadSnapshot(status: RemoteDownloadStatus.complete),
        ),
      );

      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(find.textContaining('Téléchargement'), findsNothing);
    });

    testWidgets('nothing to say when no download at all', (tester) async {
      await tester.pumpWidget(_card(RemoteDownloadSnapshot.none));

      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(find.textContaining('Téléchargement'), findsNothing);
    });
  });

  group('formatRemoteBytes', () {
    test('uses MB below a gigabyte', () {
      expect(formatRemoteBytes(512 * 1024 * 1024), equals('512 Mo'));
    });

    test('switches to GB past a gigabyte, French decimal comma', () {
      expect(formatRemoteBytes(3 * 1024 * 1024 * 1024 ~/ 2), equals('1,5 Go'));
    });
  });
}
