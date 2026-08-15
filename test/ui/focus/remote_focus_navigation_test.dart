import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kidflix/core/domain/model/remote_command.dart';
import 'package:kidflix/ui/focus/escape_to_pop.dart';
import 'package:kidflix/ui/focus/remote_focus_navigation.dart';

void main() {
  group('applyRemoteNavigation', () {
    testWidgets('an arrow moves the host focus like a key press', (
      tester,
    ) async {
      final first = FocusNode(debugLabel: 'first');
      final second = FocusNode(debugLabel: 'second');
      addTearDown(first.dispose);
      addTearDown(second.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Row(
            children: [
              Focus(
                focusNode: first,
                autofocus: true,
                child: const SizedBox(width: 50, height: 50),
              ),
              Focus(
                focusNode: second,
                child: const SizedBox(width: 50, height: 50),
              ),
            ],
          ),
        ),
      );
      await tester.pump();
      expect(first.hasPrimaryFocus, isTrue);

      applyRemoteNavigation(RemoteNavigationDirection.right);
      await tester.pump();

      expect(second.hasPrimaryFocus, isTrue);
    });

    testWidgets('OK activates whatever holds focus', (tester) async {
      var pressed = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: ElevatedButton(
              autofocus: true,
              onPressed: () => pressed++,
              child: const Text('Lire'),
            ),
          ),
        ),
      );
      await tester.pump();

      applyRemoteNavigation(RemoteNavigationDirection.select);
      await tester.pump();

      expect(pressed, equals(1));
    });

    testWidgets('back pops the pushed page', (tester) async {
      final navigator = GlobalKey<NavigatorState>();

      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigator,
          home: const EscapeToPop(child: Scaffold(body: Text('accueil'))),
        ),
      );
      unawaited(
        navigator.currentState!.push(
          MaterialPageRoute<void>(
            builder: (_) => const EscapeToPop(
              child: Scaffold(
                body: Center(
                  child: Focus(
                    autofocus: true,
                    child: SizedBox(width: 50, height: 50, child: Text('film')),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('film'), findsOneWidget);

      applyRemoteNavigation(RemoteNavigationDirection.back);
      await tester.pumpAndSettle();

      expect(find.text('film'), findsNothing);
      expect(find.text('accueil'), findsOneWidget);
    });

    testWidgets('back on the root page leaves it alone', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: EscapeToPop(
            child: Scaffold(
              body: Center(
                child: Focus(
                  autofocus: true,
                  child: SizedBox(
                    width: 50,
                    height: 50,
                    child: Text('accueil'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      applyRemoteNavigation(RemoteNavigationDirection.back);
      await tester.pumpAndSettle();

      expect(find.text('accueil'), findsOneWidget);
    });

    testWidgets('an arrow leaves the host search field instead of moving '
        'the caret', (tester) async {
      final field = FocusNode(debugLabel: 'search');
      final result = FocusNode(debugLabel: 'result');
      final navigator = GlobalKey<NavigatorState>();
      addTearDown(field.dispose);
      addTearDown(result.dispose);

      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigator,
          home: Scaffold(
            body: Column(
              children: [
                SizedBox(
                  height: 40,
                  child: TextField(focusNode: field, autofocus: true),
                ),
                Focus(
                  focusNode: result,
                  child: const SizedBox(width: 100, height: 40),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
      expect(field.hasPrimaryFocus, isTrue);

      applyRemoteNavigation(
        RemoteNavigationDirection.down,
        fallbackContext: navigator.currentContext,
      );
      await tester.pump();

      expect(result.hasPrimaryFocus, isTrue);
    });

    testWidgets('nothing focused and no fallback is a no-op', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));

      expect(
        () => applyRemoteNavigation(RemoteNavigationDirection.down),
        returnsNormally,
      );
    });
  });
}
