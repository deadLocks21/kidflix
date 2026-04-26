import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kidflix/core/domain/model/profile.dart';
import 'package:kidflix/core/domain/services/profile_pin.service.dart';
import 'package:kidflix/ui/pages/player/widgets/unlock_pin_dialog.widget.dart';

void main() {
  const main = Profile(
    id: 'main',
    name: 'Papa',
    ageCategory: AgeCategory.adulte,
    pinHash: 'hashed-1234',
    isMain: true,
  );

  Future<void> openDialog(WidgetTester tester, _FakePinService pin) async {
    final completer = <bool>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                final ok = await showUnlockPinDialog(
                  context,
                  mainProfile: main,
                  pinService: pin,
                );
                completer.add(ok);
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    addTearDown(() => completer);
  }

  Future<List<bool>> openAndCapture(
    WidgetTester tester,
    _FakePinService pin,
  ) async {
    final captured = <bool>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                final ok = await showUnlockPinDialog(
                  context,
                  mainProfile: main,
                  pinService: pin,
                );
                captured.add(ok);
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    return captured;
  }

  testWidgets('dialog shows the prompt and a Cancel button', (tester) async {
    final pin = _FakePinService(validPin: '1234');
    await openDialog(tester, pin);
    expect(find.text('Code parent'), findsOneWidget);
    expect(find.text('Saisis le code du profil principal'), findsOneWidget);
    expect(find.text('Annuler'), findsOneWidget);
  });

  testWidgets('correct PIN dismisses with true', (tester) async {
    final pin = _FakePinService(validPin: '1234');
    final captured = await openAndCapture(tester, pin);

    await tester.enterText(find.byType(TextField), '1234');
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(captured, [true]);
    expect(pin.calls, 1);
  });

  testWidgets('incorrect PIN keeps the dialog open and shows error', (tester) async {
    final pin = _FakePinService(validPin: '1234');
    final captured = await openAndCapture(tester, pin);

    await tester.enterText(find.byType(TextField), '0000');
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Code incorrect'), findsOneWidget);
    expect(captured, isEmpty);
  });

  testWidgets('Annuler dismisses with false', (tester) async {
    final pin = _FakePinService(validPin: '1234');
    final captured = await openAndCapture(tester, pin);

    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(captured, [false]);
    expect(pin.calls, 0);
  });

  testWidgets('user can retry after an incorrect PIN', (tester) async {
    final pin = _FakePinService(validPin: '1234');
    final captured = await openAndCapture(tester, pin);

    await tester.enterText(find.byType(TextField), '0000');
    await tester.pumpAndSettle();
    expect(find.text('Code incorrect'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '1234');
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(captured, [true]);
    expect(pin.calls, 2);
  });
}

class _FakePinService implements ProfilePinService {
  final String validPin;
  int calls = 0;

  _FakePinService({required this.validPin});

  @override
  Future<String> hash(String rawPin) async => 'hashed-$rawPin';

  @override
  Future<bool> verify(String rawPin, String bcryptHash) async {
    calls += 1;
    return rawPin == validPin;
  }
}
