import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kidflix/ui/focus/escape_to_pop.dart';

Widget _harness() => MaterialApp(
  builder: (context, child) =>
      EscapeToPop(child: child ?? const SizedBox.shrink()),
  home: const _RootPage(),
);

class _RootPage extends StatelessWidget {
  const _RootPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          const Text('racine'),
          TextButton(
            autofocus: true,
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute<void>(builder: (_) => const _SubPage())),
            child: const Text('ouvrir la sous-page'),
          ),
        ],
      ),
    );
  }
}

class _SubPage extends StatelessWidget {
  const _SubPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          const Text('sous-page'),
          TextButton(
            autofocus: true,
            onPressed: () => showDialog<void>(
              context: context,
              barrierDismissible: false,
              builder: (_) =>
                  const AlertDialog(content: Text('modale scellée')),
            ),
            child: const Text('ouvrir la modale'),
          ),
        ],
      ),
    );
  }
}

Future<void> _escape(WidgetTester tester) async {
  await tester.sendKeyEvent(LogicalKeyboardKey.escape);
  await tester.pumpAndSettle();
}

void main() {
  group('EscapeToPop', () {
    testWidgets('is inert on a root page — a child mashing keys cannot '
        'navigate away', (tester) async {
      await tester.pumpWidget(_harness());
      await tester.pumpAndSettle();

      await _escape(tester);

      expect(find.text('racine'), findsOneWidget);
    });

    testWidgets('pops a pushed page', (tester) async {
      await tester.pumpWidget(_harness());
      await tester.pumpAndSettle();
      await tester.tap(find.text('ouvrir la sous-page'));
      await tester.pumpAndSettle();
      expect(find.text('sous-page'), findsOneWidget);

      await _escape(tester);

      expect(find.text('sous-page'), findsNothing);
      expect(find.text('racine'), findsOneWidget);
    });

    testWidgets('leaves a barrierDismissible: false modal sealed, and does '
        'not pop the page underneath it either', (tester) async {
      await tester.pumpWidget(_harness());
      await tester.pumpAndSettle();
      await tester.tap(find.text('ouvrir la sous-page'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ouvrir la modale'));
      await tester.pumpAndSettle();
      expect(find.text('modale scellée'), findsOneWidget);

      await _escape(tester);

      expect(
        find.text('modale scellée'),
        findsOneWidget,
        reason:
            'this is what keeps the kids-lock PIN prompt and the resume '
            'dialog closed to the keyboard',
      );
      expect(find.text('sous-page'), findsOneWidget);
    });
  });
}
