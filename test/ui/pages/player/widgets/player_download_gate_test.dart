import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kidflix/ui/pages/player/widgets/player_download_gate.widget.dart';

void main() {
  group('PlayerDownloadGate', () {
    testWidgets('renders title, linear progress and caption with known total', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlayerDownloadGate(
              movieTitle: 'Totoro',
              bytesReceived: 12_300_000,
              bytesTotal: 158_000_000,
              onCancel: () {},
            ),
          ),
        ),
      );

      expect(find.text('Totoro'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.textContaining('11.7 MB'), findsOneWidget);
      expect(find.textContaining('150.7 MB'), findsOneWidget);
      expect(find.text('Annuler'), findsOneWidget);
    });

    testWidgets('falls back to indeterminate progress when total is null', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlayerDownloadGate(
              movieTitle: 'Totoro',
              bytesReceived: 1_048_576,
              onCancel: () {},
            ),
          ),
        ),
      );

      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.text('1.0 MB'), findsOneWidget);
      expect(find.textContaining('/'), findsNothing);
    });

    testWidgets('cancel button invokes callback', (tester) async {
      var cancelled = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlayerDownloadGate(
              movieTitle: 'Totoro',
              bytesReceived: 0,
              bytesTotal: 100,
              onCancel: () => cancelled++,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Annuler'));
      await tester.pump();
      expect(cancelled, 1);
    });
  });

  group('formatBytesMB', () {
    test('formats 1 MiB as 1.0 MB', () {
      expect(formatBytesMB(1024 * 1024), '1.0 MB');
    });
    test('rounds to one decimal', () {
      expect(formatBytesMB(1_234_567), '1.2 MB');
    });
    test('formats zero', () {
      expect(formatBytesMB(0), '0.0 MB');
    });
  });
}
