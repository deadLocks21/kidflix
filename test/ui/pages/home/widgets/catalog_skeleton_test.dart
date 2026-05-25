import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kidflix/ui/pages/home/widgets/catalog_skeleton.widget.dart';
import 'package:kidflix/ui/theme/app_theme_data.dart';

/// Renders under the real app theme so the regression below actually
/// exercises the trap: the theme leaves `surfaceContainer*` undefined, so
/// those roles resolve to the pure-black `surface`. A skeleton painted with
/// them would be black-on-black (invisible) — which is the bug this guards.
Widget _harness() => MaterialApp(
  theme: AppThemeData.buildDarkTheme(),
  home: const Scaffold(body: CatalogSkeleton()),
);

void main() {
  group('CatalogSkeleton', () {
    testWidgets('paints placeholder boxes visibly lighter than the '
        'black background', (tester) async {
      await tester.pumpWidget(_harness());
      // Advance into the pulse so we sample a real animated frame.
      await tester.pump(const Duration(milliseconds: 150));

      final boxes = tester
          .widgetList<Container>(
            find.descendant(
              of: find.byType(CatalogSkeleton),
              matching: find.byType(Container),
            ),
          )
          .map((c) => c.decoration)
          .whereType<BoxDecoration>()
          .where((d) => d.color != null)
          .toList();

      expect(boxes, isNotEmpty, reason: 'skeleton should paint filled boxes');
      for (final d in boxes) {
        // Pure black has luminance 0; any visible grey is clearly above.
        expect(
          d.color!.computeLuminance(),
          greaterThan(0.005),
          reason:
              'skeleton boxes must stay visible on the pure-black surface — '
              'never paint with a colour that resolves to black',
        );
      }
    });
  });
}
