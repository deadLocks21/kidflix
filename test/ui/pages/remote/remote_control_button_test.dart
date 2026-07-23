import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kidflix/ui/pages/home/widgets/remote_control_button.widget.dart';
import 'package:kidflix/ui/pages/remote/widgets/remote_device_list.widget.dart';
import 'package:kidflix/ui/pages/remote/widgets/remote_host_panel.widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _app() => const ProviderScope(
  child: MaterialApp(
    home: Scaffold(
      appBar: null,
      body: Row(children: [RemoteControlButton()]),
    ),
  ),
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('RemoteControlButton', () {
    testWidgets('renders the idle cast icon by default', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pump();

      expect(find.byIcon(Icons.cast), findsOneWidget);
      expect(find.byIcon(Icons.cast_connected), findsNothing);
    });

    testWidgets('carries a French tooltip', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pump();

      final button = tester.widget<IconButton>(find.byType(IconButton));
      expect(button.tooltip, equals('Télécommande'));
    });

    testWidgets('opens the sheet with both halves', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pump();

      await tester.tap(find.byType(IconButton));
      await tester.pumpAndSettle();

      // The sheet is one surface for both roles: pick a device to drive,
      // or let this device be driven.
      expect(find.text('Télécommande'), findsOneWidget);
      expect(find.byType(RemoteDeviceList), findsOneWidget);
      expect(find.byType(RemoteHostPanel), findsOneWidget);
      expect(find.text('Diffuser vers'), findsOneWidget);
      expect(find.text('Cet appareil'), findsOneWidget);
    });

    testWidgets('hosting is off by default and shows the explanatory subtitle', (
      tester,
    ) async {
      await tester.pumpWidget(_app());
      await tester.pump();
      await tester.tap(find.byType(IconButton));
      await tester.pumpAndSettle();

      final toggle = tester.widget<SwitchListTile>(find.byType(SwitchListTile));
      expect(toggle.value, isFalse);
      expect(
        find.text('Les autres appareils ne peuvent pas piloter celui-ci.'),
        findsOneWidget,
      );
      // No pairing code is shown while the server is off — there is
      // nothing to pair with yet.
      expect(find.text('Code d’association'), findsNothing);
    });

    testWidgets('offers the manual pairing fallback', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pump();
      await tester.tap(find.byType(IconButton));
      await tester.pumpAndSettle();

      // mDNS does not survive every network; typing an IP must stay
      // possible.
      expect(find.text('Ajouter par adresse IP'), findsOneWidget);
    });

    testWidgets('explains why the device list is empty', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pump();
      await tester.tap(find.byType(IconButton));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Aucun appareil trouvé'),
        findsOneWidget,
      );
    });
  });
}
