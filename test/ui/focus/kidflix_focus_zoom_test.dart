import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kidflix/ui/focus/keyboard_mode.dart';
import 'package:kidflix/ui/focus/kidflix_focus_zoom.widget.dart';
import 'package:kidflix/ui/focus/kidflix_focusable.widget.dart';
import 'package:kidflix/ui/theme/app_theme_data.dart';

final _first = FocusNode(debugLabel: 'premier');
final _second = FocusNode(debugLabel: 'second');

Widget _harness() => MaterialApp(
  theme: AppThemeData.buildDarkTheme(),
  builder: (context, child) =>
      KeyboardModeScope(child: child ?? const SizedBox.shrink()),
  home: Scaffold(
    appBar: AppBar(
      title: const Text('Qui regarde ?'),
      actions: [
        KidflixFocusZoom(
          child: IconButton(
            focusNode: _first,
            autofocus: true,
            icon: const Icon(Icons.search),
            onPressed: () {},
          ),
        ),
        KidflixFocusZoom(
          child: IconButton(
            focusNode: _second,
            icon: const Icon(Icons.logout),
            onPressed: () {},
          ),
        ),
      ],
    ),
    body: const SizedBox.expand(),
  ),
);

double _scaleOf(WidgetTester tester, FocusNode node) {
  final zoom = find.ancestor(
    of: find.byWidgetPredicate((w) => w is IconButton && w.focusNode == node),
    matching: find.byType(AnimatedScale),
  );
  return tester.widget<AnimatedScale>(zoom.first).scale;
}

void main() {
  group('KidflixFocusZoom', () {
    testWidgets('grows a focused button only once the keyboard is in use', (
      tester,
    ) async {
      await tester.pumpWidget(_harness());
      await tester.pumpAndSettle();
      expect(_scaleOf(tester, _first), 1);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(_scaleOf(tester, _first), KidflixFocusable.defaultScale);
      expect(_scaleOf(tester, _second), 1);

      await tester.tapAt(const Offset(400, 400));
      await tester.pumpAndSettle();
      expect(_scaleOf(tester, _first), 1);
    });

    testWidgets('the wrapper adds no stop of its own to the tab order', (
      tester,
    ) async {
      await tester.pumpWidget(_harness());
      await tester.pumpAndSettle();
      expect(_first.hasPrimaryFocus, isTrue);

      // The first Tab only turns the ring on, like any other navigation key.
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(_first.hasPrimaryFocus, isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();

      expect(
        _second.hasPrimaryFocus,
        isTrue,
        reason:
            'the zoom node must stay unfocusable and skipped, or every '
            'button would cost two tabs to reach',
      );
    });

    testWidgets('the zoom follows the button it wraps, not its neighbour', (
      tester,
    ) async {
      await tester.pumpWidget(_harness());
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();

      _second.requestFocus();
      await tester.pumpAndSettle();

      expect(_scaleOf(tester, _first), 1);
      expect(_scaleOf(tester, _second), KidflixFocusable.defaultScale);
    });
  });
}
