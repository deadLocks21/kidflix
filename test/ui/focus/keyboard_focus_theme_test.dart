import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kidflix/ui/focus/keyboard_focus_theme.dart';
import 'package:kidflix/ui/focus/keyboard_mode.dart';
import 'package:kidflix/ui/focus/kidflix_focusable.widget.dart';
import 'package:kidflix/ui/theme/app_theme_data.dart';

late ThemeData _ambientTheme;

/// Reproduces the reported case verbatim: the logout action of the profile
/// selection app bar. [AppBar] rebuilds an [IconButtonTheme] for its actions,
/// so this also guards against it dropping the ring on the way.
Widget _harness() => MaterialApp(
  theme: AppThemeData.buildDarkTheme(),
  builder: (context, child) => KeyboardModeScope(
    child: KeyboardFocusTheme(child: child ?? const SizedBox.shrink()),
  ),
  home: Scaffold(
    appBar: AppBar(
      title: const Text('Qui regarde ?'),
      actions: [
        IconButton(
          autofocus: true,
          tooltip: 'Se déconnecter',
          icon: const Icon(Icons.logout),
          onPressed: () {},
        ),
      ],
    ),
    body: Builder(
      builder: (context) {
        _ambientTheme = Theme.of(context);
        return const SizedBox.expand();
      },
    ),
  ),
);

/// The side [ButtonStyleButton] resolved into the shape it actually paints.
///
/// Beware [BorderSide.none]: it is opaque black at zero width, so "no ring"
/// has to be read off the width, never off the colour's alpha.
BorderSide? _paintedSide(WidgetTester tester) {
  final material = tester.widget<Material>(
    find
        .descendant(
          of: find.byType(IconButton),
          matching: find.byType(Material),
        )
        .first,
  );
  final shape = material.shape;
  return shape is OutlinedBorder ? shape.side : null;
}

/// The fill the button paints under that side.
Color? _paintedFill(WidgetTester tester) {
  final material = tester.widget<Material>(
    find
        .descendant(
          of: find.byType(IconButton),
          matching: find.byType(Material),
        )
        .first,
  );
  return material.color;
}

bool _ringPainted(WidgetTester tester) {
  final side = _paintedSide(tester);
  return side != null && side.style == BorderStyle.solid && side.width > 0;
}

/// An app bar action is flat ; the filled variant is the one whose fill
/// used to match the ring exactly.
Widget _filledHarness() => MaterialApp(
  theme: AppThemeData.buildDarkTheme(),
  builder: (context, child) => KeyboardModeScope(
    child: KeyboardFocusTheme(child: child ?? const SizedBox.shrink()),
  ),
  home: Scaffold(
    body: Center(
      child: IconButton.filled(
        autofocus: true,
        icon: const Icon(Icons.play_arrow_rounded),
        onPressed: () {},
      ),
    ),
  ),
);

void main() {
  group('KeyboardFocusTheme', () {
    testWidgets('an app bar icon button shows the primary ring once the '
        'keyboard is in use', (tester) async {
      await tester.pumpWidget(_harness());
      await tester.pumpAndSettle();

      expect(
        _ringPainted(tester),
        isFalse,
        reason: 'mouse mode paints no ring, even though the button is focused',
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();

      final scheme = AppThemeData.buildDarkTheme().colorScheme;
      final side = _paintedSide(tester);
      expect(side, isNotNull);
      expect(side!.color, KidflixFocusable.ringColor(scheme));
      expect(side.width, KidflixFocusable.ringWidth);
      expect(
        side.color,
        isNot(scheme.primary),
        reason:
            'the brand red is the fill of every primary button — a red '
            'ring on one is red on red',
      );
    });

    testWidgets('the focus wash for tiles becomes visible on the black '
        'surface', (tester) async {
      await tester.pumpWidget(_harness());
      await tester.pumpAndSettle();
      final beforeAlpha = _ambientTheme.focusColor.a;

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();

      // ListTile, CheckboxListTile, ExpansionTile and the popup menu items
      // all fall back to this one colour.
      expect(_ambientTheme.focusColor.a, greaterThan(beforeAlpha));
      expect(
        _ambientTheme.focusColor.withValues(alpha: 1),
        KidflixFocusable.ringColor(AppThemeData.buildDarkTheme().colorScheme),
      );
    });

    testWidgets('the ring contrasts with the fill it is drawn on', (
      tester,
    ) async {
      // The regression this guards: the ring was `colorScheme.primary`,
      // which is also the fill of every primary button. Present, and
      // perfectly invisible.
      await tester.pumpWidget(_filledHarness());
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();

      final side = _paintedSide(tester);
      final fill = _paintedFill(tester);
      expect(side, isNotNull);
      expect(fill, isNotNull);
      final contrast =
          (side!.color.computeLuminance() - fill!.computeLuminance()).abs();
      expect(
        contrast,
        greaterThan(0.3),
        reason: 'ring ${side.color} on fill $fill is not a focus indicator',
      );
    });

    testWidgets('going back to the mouse drops the ring again', (tester) async {
      await tester.pumpWidget(_harness());
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(_ringPainted(tester), isTrue);

      await tester.tapAt(const Offset(400, 400));
      await tester.pumpAndSettle();

      expect(_ringPainted(tester), isFalse);
    });
  });
}
