import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kidflix/core/domain/model/remote_playback_state.dart';
import 'package:kidflix/ui/focus/host_text_input_observer.dart';

void main() {
  group('HostTextInputObserver', () {
    late List<RemoteTextInputSnapshot> seen;
    late HostTextInputObserver observer;

    setUp(() {
      seen = [];
      observer = HostTextInputObserver(onChanged: seen.add);
    });

    Future<void> pumpField(
      WidgetTester tester, {
      required FocusNode field,
      required FocusNode other,
      TextEditingController? controller,
      bool obscure = false,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                TextField(
                  focusNode: field,
                  controller: controller,
                  obscureText: obscure,
                ),
                Focus(
                  focusNode: other,
                  child: const SizedBox(width: 50, height: 50),
                ),
              ],
            ),
          ),
        ),
      );
    }

    testWidgets('reports the field the host focuses, and its text', (
      tester,
    ) async {
      final field = FocusNode();
      final other = FocusNode();
      final controller = TextEditingController(text: 'dino');
      addTearDown(field.dispose);
      addTearDown(other.dispose);
      addTearDown(controller.dispose);

      await pumpField(
        tester,
        field: field,
        other: other,
        controller: controller,
      );
      observer.start();
      addTearDown(observer.stop);

      field.requestFocus();
      await tester.pump();

      expect(seen.last.active, isTrue);
      expect(seen.last.value, equals('dino'));
      expect(seen.last.obscured, isFalse);
    });

    testWidgets('reports the field going away when focus leaves it', (
      tester,
    ) async {
      final field = FocusNode();
      final other = FocusNode();
      addTearDown(field.dispose);
      addTearDown(other.dispose);

      await pumpField(tester, field: field, other: other);
      observer.start();
      addTearDown(observer.stop);

      field.requestFocus();
      await tester.pump();
      expect(seen.last.active, isTrue);

      other.requestFocus();
      await tester.pump();

      expect(seen.last.active, isFalse);
    });

    testWidgets('follows text typed on the host itself', (tester) async {
      final field = FocusNode();
      final other = FocusNode();
      addTearDown(field.dispose);
      addTearDown(other.dispose);

      await pumpField(tester, field: field, other: other);
      observer.start();
      addTearDown(observer.stop);

      field.requestFocus();
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'zébre');
      await tester.pump();

      expect(seen.last.value, equals('zébre'));
    });

    testWidgets('never mirrors the content of an obscured field', (
      tester,
    ) async {
      final field = FocusNode();
      final other = FocusNode();
      final controller = TextEditingController(text: '1234');
      addTearDown(field.dispose);
      addTearDown(other.dispose);
      addTearDown(controller.dispose);

      await pumpField(
        tester,
        field: field,
        other: other,
        controller: controller,
        obscure: true,
      );
      observer.start();
      addTearDown(observer.stop);

      field.requestFocus();
      await tester.pump();

      expect(seen.last.obscured, isTrue);
      // The value never reaches the wire, whatever the snapshot holds.
      expect(seen.last.toJson()['value'], isEmpty);
    });
  });

  group('setHostTextInput', () {
    testWidgets('types into the focused field and fires its onChanged', (
      tester,
    ) async {
      final field = FocusNode();
      addTearDown(field.dispose);
      String? changed;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TextField(
              focusNode: field,
              autofocus: true,
              onChanged: (value) => changed = value,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(setHostTextInput('licorne'), isTrue);
      await tester.pump();

      expect(changed, equals('licorne'));
      expect(find.text('licorne'), findsOneWidget);
    });

    testWidgets('reports the miss when no field is focused', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));

      expect(setHostTextInput('licorne'), isFalse);
    });
  });
}
