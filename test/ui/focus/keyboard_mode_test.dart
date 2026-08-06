import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kidflix/ui/focus/keyboard_mode.dart';
import 'package:kidflix/ui/focus/kidflix_focusable.widget.dart';
import 'package:kidflix/ui/theme/app_theme_data.dart';

final _first = FocusNode(debugLabel: 'first');
final _second = FocusNode(debugLabel: 'second');

Widget _harness() => MaterialApp(
  theme: AppThemeData.buildDarkTheme(),
  builder: (context, child) =>
      KeyboardModeScope(child: child ?? const SizedBox.shrink()),
  home: Scaffold(
    body: Row(
      children: [
        KidflixFocusable(
          focusNode: _first,
          autofocus: true,
          onTap: () {},
          child: const SizedBox(width: 100, height: 100),
        ),
        KidflixFocusable(
          focusNode: _second,
          onTap: () {},
          child: const SizedBox(width: 100, height: 100),
        ),
      ],
    ),
  ),
);

/// The ring is a [BoxDecoration] border painted in front of the child, so
/// a visible ring means a non-transparent `foregroundDecoration` border.
bool _ringVisible(WidgetTester tester, FocusNode node) {
  final containers = tester.widgetList<AnimatedContainer>(
    find.descendant(
      of: find.byWidgetPredicate(
        (w) => w is KidflixFocusable && w.focusNode == node,
      ),
      matching: find.byType(AnimatedContainer),
    ),
  );
  return containers.any((c) {
    final decoration = c.foregroundDecoration;
    if (decoration is! BoxDecoration) return false;
    return decoration.border?.top.color.a != 0;
  });
}

void main() {
  group('KeyboardModeScope', () {
    testWidgets('the first arrow press reveals the ring without moving '
        'focus, the next one moves it', (tester) async {
      await tester.pumpWidget(_harness());
      await tester.pumpAndSettle();

      // Autofocus placed focus, but the user is not on the keyboard yet.
      expect(_first.hasFocus, isTrue);
      expect(_ringVisible(tester, _first), isFalse);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(
        _first.hasFocus,
        isTrue,
        reason:
            'the reveal press must not move focus past the element the '
            'user expected to start from',
      );
      expect(_ringVisible(tester, _first), isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(_second.hasFocus, isTrue);
      expect(_ringVisible(tester, _second), isTrue);
    });

    testWidgets('a pointer press hides the ring but keeps the focus', (
      tester,
    ) async {
      await tester.pumpWidget(_harness());
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(_ringVisible(tester, _first), isTrue);

      await tester.tapAt(const Offset(400, 400));
      await tester.pumpAndSettle();

      expect(_ringVisible(tester, _first), isFalse);
      expect(
        _first.hasFocus,
        isTrue,
        reason:
            'going back to the mouse only hides the ring — the next key '
            'press should carry on from where the focus already is',
      );
    });

    testWidgets('Enter activates the focused element', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) =>
              KeyboardModeScope(child: child ?? const SizedBox.shrink()),
          home: Scaffold(
            body: KidflixFocusable(
              autofocus: true,
              onTap: () => taps++,
              child: const SizedBox(width: 100, height: 100),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(taps, 1);
    });
  });
}
