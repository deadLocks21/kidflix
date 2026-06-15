import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kidflix/ui/theme/app_colors.dart';
import 'package:kidflix/ui/widgets/pin_pad.widget.dart';

Widget _host({
  required Future<bool> Function(String) onSubmit,
  String title = 'Code',
  Widget? footer,
  TargetPlatform platform = TargetPlatform.android,
}) {
  return MaterialApp(
    theme: ThemeData(extensions: const [AppColors.dark()], platform: platform),
    home: Scaffold(
      body: PinPad(title: title, onSubmit: onSubmit, footer: footer),
    ),
  );
}

Future<void> _enter(WidgetTester tester, String digits) async {
  for (final d in digits.split('')) {
    await tester.tap(find.text(d));
    await tester.pump();
  }
}

void main() {
  testWidgets('submits the full code once the length is reached', (
    tester,
  ) async {
    final submitted = <String>[];
    await tester.pumpWidget(
      _host(
        onSubmit: (pin) async {
          submitted.add(pin);
          return true;
        },
      ),
    );
    await tester.pumpAndSettle();

    await _enter(tester, '1234');
    await tester.pumpAndSettle();

    expect(submitted, ['1234']);
  });

  testWidgets('does not submit before the code is complete', (tester) async {
    final submitted = <String>[];
    await tester.pumpWidget(
      _host(
        onSubmit: (pin) async {
          submitted.add(pin);
          return true;
        },
      ),
    );
    await tester.pumpAndSettle();

    await _enter(tester, '12');
    await tester.pumpAndSettle();

    expect(submitted, isEmpty);
  });

  testWidgets('backspace removes the last entered digit', (tester) async {
    final submitted = <String>[];
    await tester.pumpWidget(
      _host(
        onSubmit: (pin) async {
          submitted.add(pin);
          return true;
        },
      ),
    );
    await tester.pumpAndSettle();

    await _enter(tester, '123');
    await tester.tap(find.byIcon(Icons.backspace_outlined));
    await tester.pump();
    await _enter(tester, '45'); // 12 -> 124 -> 1245
    await tester.pumpAndSettle();

    expect(submitted, ['1245']);
  });

  testWidgets('places the footer in the slot to the left of the 0 key', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        onSubmit: (_) async => true,
        footer: const Icon(Icons.fingerprint, key: Key('biometric')),
      ),
    );
    await tester.pumpAndSettle();

    final footerCenter = tester.getCenter(find.byKey(const Key('biometric')));
    final zeroCenter = tester.getCenter(find.text('0'));
    // Same row as 0 (aligned vertically), immediately to its left.
    expect(footerCenter.dx, lessThan(zeroCenter.dx));
    expect((footerCenter.dy - zeroCenter.dy).abs(), lessThan(1));
  });

  testWidgets('clears after a failed attempt so the user can retry', (
    tester,
  ) async {
    final submitted = <String>[];
    await tester.pumpWidget(
      _host(
        onSubmit: (pin) async {
          submitted.add(pin);
          return false; // always rejected
        },
      ),
    );
    await tester.pumpAndSettle();

    await _enter(tester, '1111');
    await tester.pumpAndSettle(); // shake + clear

    await _enter(tester, '2222');
    await tester.pumpAndSettle();

    expect(submitted, ['1111', '2222']);
  });

  testWidgets('hides the keypad on desktop and shows a typing hint', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(onSubmit: (_) async => true, platform: TargetPlatform.windows),
    );
    await tester.pumpAndSettle();

    expect(find.text('1'), findsNothing);
    expect(find.text('5'), findsNothing);
    expect(find.text('0'), findsNothing);
    expect(find.byIcon(Icons.backspace_outlined), findsNothing);
    expect(find.textContaining('clavier'), findsOneWidget);
  });

  testWidgets('accepts physical keyboard input on desktop', (tester) async {
    final submitted = <String>[];
    await tester.pumpWidget(
      _host(
        platform: TargetPlatform.windows,
        onSubmit: (pin) async {
          submitted.add(pin);
          return true;
        },
      ),
    );
    await tester.pumpAndSettle();

    for (final key in [
      LogicalKeyboardKey.digit1,
      LogicalKeyboardKey.digit2,
      LogicalKeyboardKey.digit3,
      LogicalKeyboardKey.digit4,
    ]) {
      await tester.sendKeyEvent(key);
      await tester.pump();
    }
    await tester.pumpAndSettle();

    expect(submitted, ['1234']);
  });
}
