import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kidflix/ui/pages/player/widgets/lock_button.widget.dart';
import 'package:kidflix/ui/pages/player/widgets/unlock_button.widget.dart';

void main() {
  testWidgets('LockButton renders an open padlock icon and fires onTap', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: LockButton(onTap: () => taps++)),
      ),
    );
    expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    await tester.tap(find.byType(LockButton));
    expect(taps, 1);
  });

  testWidgets('UnlockButton renders a closed padlock icon and fires onTap', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: UnlockButton(onTap: () => taps++)),
      ),
    );
    expect(find.byIcon(Icons.lock), findsOneWidget);
    await tester.tap(find.byType(UnlockButton));
    expect(taps, 1);
  });
}
