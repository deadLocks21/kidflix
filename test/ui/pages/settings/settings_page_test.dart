import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kidflix/infrastructure/providers/app_version.provider.dart';
import 'package:kidflix/ui/pages/settings/settings.page.dart';

Widget _app(List<Object> overrides) => ProviderScope(
  overrides: overrides.cast(),
  child: const MaterialApp(home: SettingsPage()),
);

void main() {
  group('SettingsPage version label', () {
    testWidgets('shows the version once resolved', (tester) async {
      await tester.pumpWidget(
        _app([appVersionProvider.overrideWith((ref) async => '1.14.3 (1)')]),
      );
      await tester.pumpAndSettle();
      expect(find.text('v1.14.3 (1)'), findsOneWidget);
    });

    testWidgets('shows nothing while the version is loading', (tester) async {
      final pending = Completer<String>();
      await tester.pumpWidget(
        _app([appVersionProvider.overrideWith((ref) => pending.future)]),
      );
      expect(find.textContaining('v1.'), findsNothing);
    });

    testWidgets('shows nothing when the lookup fails', (tester) async {
      await tester.pumpWidget(
        _app([
          appVersionProvider.overrideWith(
            (ref) async => throw StateError('no platform'),
          ),
        ]),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('v1.'), findsNothing);
    });
  });
}
