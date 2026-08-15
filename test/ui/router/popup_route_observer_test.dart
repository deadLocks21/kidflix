import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kidflix/ui/router/popup_route_observer.dart';

void main() {
  group('PopupRouteObserver', () {
    late PopupRouteObserver observer;
    late GlobalKey<NavigatorState> navigator;

    setUp(() {
      observer = PopupRouteObserver();
      navigator = GlobalKey<NavigatorState>();
    });

    Future<void> pump(WidgetTester tester) => tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        navigatorObservers: [observer],
        home: const Scaffold(body: Text('accueil')),
      ),
    );

    testWidgets('a dialog raises the flag and closing it lowers it', (
      tester,
    ) async {
      await pump(tester);
      expect(observer.isOpen.value, isFalse);

      final answered = showDialog<bool>(
        context: navigator.currentContext!,
        builder: (_) => const AlertDialog(title: Text('Reprendre ?')),
      );
      await tester.pumpAndSettle();
      expect(observer.isOpen.value, isTrue);

      navigator.currentState!.pop(true);
      await tester.pumpAndSettle();
      await answered;

      expect(observer.isOpen.value, isFalse);
    });

    testWidgets('closing the top of two popups keeps the flag up', (
      tester,
    ) async {
      await pump(tester);

      for (var i = 0; i < 2; i++) {
        unawaited(
          showDialog<void>(
            context: navigator.currentContext!,
            builder: (_) => AlertDialog(title: Text('popup $i')),
          ),
        );
        await tester.pumpAndSettle();
      }
      expect(observer.isOpen.value, isTrue);

      navigator.currentState!.pop();
      await tester.pumpAndSettle();

      expect(observer.isOpen.value, isTrue);

      navigator.currentState!.pop();
      await tester.pumpAndSettle();

      expect(observer.isOpen.value, isFalse);
    });

    testWidgets('a pushed page is not a popup', (tester) async {
      await pump(tester);

      unawaited(
        navigator.currentState!.push(
          MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('lecteur')),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(observer.isOpen.value, isFalse);
    });
  });
}
