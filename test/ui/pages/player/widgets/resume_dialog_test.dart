import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kidflix/ui/pages/player/widgets/resume_dialog.widget.dart';

void main() {
  Future<void> pumpDialogHost(
    WidgetTester tester, {
    required Duration position,
    required void Function(ResumeChoice?) onClose,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  final choice = await showResumeDialog(context, position);
                  onClose(choice);
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  testWidgets('shows title and labels for a 30-minute progress', (tester) async {
    await pumpDialogHost(
      tester,
      position: const Duration(minutes: 30),
      onClose: (_) {},
    );

    expect(find.text('Reprendre la lecture ?'), findsOneWidget);
    expect(find.text('Reprendre à 30 min'), findsOneWidget);
    expect(find.text('Recommencer'), findsOneWidget);
  });

  testWidgets('tap on "Reprendre" resolves with resume', (tester) async {
    ResumeChoice? received;
    await pumpDialogHost(
      tester,
      position: const Duration(minutes: 30),
      onClose: (c) => received = c,
    );
    await tester.tap(find.textContaining('Reprendre à'));
    await tester.pumpAndSettle();
    expect(received, ResumeChoice.resume);
  });

  testWidgets('tap on "Recommencer" resolves with restart', (tester) async {
    ResumeChoice? received;
    await pumpDialogHost(
      tester,
      position: const Duration(minutes: 30),
      onClose: (c) => received = c,
    );
    await tester.tap(find.text('Recommencer'));
    await tester.pumpAndSettle();
    expect(received, ResumeChoice.restart);
  });
}
