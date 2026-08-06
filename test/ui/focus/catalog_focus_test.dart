import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kidflix/core/application/dtos/catalog_item.dto.dart';
import 'package:kidflix/core/application/dtos/catalog_row.dto.dart';
import 'package:kidflix/core/application/dtos/movie.dto.dart';
import 'package:kidflix/ui/focus/catalog_focus.dart';
import 'package:kidflix/ui/focus/keyboard_mode.dart';
import 'package:kidflix/ui/pages/home/widgets/catalog_row.widget.dart';
import 'package:kidflix/ui/pages/home/widgets/movie_card.widget.dart';
import 'package:kidflix/ui/theme/app_theme_data.dart';

CatalogRowDto _row(String label, int count) => CatalogRowDto(
  label: label,
  type: 'genre',
  items: <CatalogItemDto>[
    for (var i = 0; i < count; i++)
      MovieDto(
        id: '$label-$i',
        title: '$label $i',
        duration: const Duration(minutes: 90),
        ageCategory: 'enfant',
      ),
  ],
);

/// Mirrors the home page's own list: same scope, same cache extent, same
/// row widget. Only the data source is faked.
Widget _harness(List<CatalogRowDto> rows, {bool enabled = true}) => MaterialApp(
  theme: AppThemeData.buildDarkTheme(),
  builder: (context, child) =>
      KeyboardModeScope(child: child ?? const SizedBox.shrink()),
  home: Scaffold(
    body: ExcludeFocus(
      excluding: !enabled,
      child: CatalogFocusScope(
        enabled: enabled,
        child: CustomScrollView(
          cacheExtent: 400,
          slivers: [
            SliverList.builder(
              itemCount: rows.length,
              itemBuilder: (_, i) =>
                  CatalogRowWidget(index: i, row: rows[i], onMovieTap: (_) {}),
            ),
          ],
        ),
      ),
    ),
  ),
);

/// Focused poster as `(row, column)`, read off the node's debug label.
String? _focused() => FocusManager.instance.primaryFocus?.debugLabel;

Future<void> _press(
  WidgetTester tester,
  LogicalKeyboardKey key, {
  int times = 1,
}) async {
  for (var i = 0; i < times; i++) {
    await tester.sendKeyEvent(key);
    await tester.pumpAndSettle();
  }
}

/// Burns the press that only turns the focus ring on.
Future<void> _enterKeyboardMode(WidgetTester tester) =>
    _press(tester, LogicalKeyboardKey.arrowRight);

void main() {
  group('catalog keyboard traversal', () {
    testWidgets('the first poster takes focus on mount', (tester) async {
      await tester.pumpWidget(_harness([_row('A', 6), _row('B', 6)]));
      await tester.pumpAndSettle();

      expect(_focused(), 'catalog(0, 0)');
    });

    testWidgets('right and left walk along a row', (tester) async {
      await tester.pumpWidget(_harness([_row('A', 6)]));
      await tester.pumpAndSettle();
      await _enterKeyboardMode(tester);

      await _press(tester, LogicalKeyboardKey.arrowRight, times: 3);
      expect(_focused(), 'catalog(0, 3)');

      await _press(tester, LogicalKeyboardKey.arrowLeft);
      expect(_focused(), 'catalog(0, 2)');
    });

    testWidgets('down carries the column over to the row below', (
      tester,
    ) async {
      await tester.pumpWidget(_harness([_row('A', 6), _row('B', 6)]));
      await tester.pumpAndSettle();
      await _enterKeyboardMode(tester);

      await _press(tester, LogicalKeyboardKey.arrowRight, times: 2);
      expect(_focused(), 'catalog(0, 2)');

      await _press(tester, LogicalKeyboardKey.arrowDown);
      expect(_focused(), 'catalog(1, 2)');

      await _press(tester, LogicalKeyboardKey.arrowUp);
      expect(_focused(), 'catalog(0, 2)');
    });

    testWidgets('down into a shorter row clamps to its last poster', (
      tester,
    ) async {
      await tester.pumpWidget(_harness([_row('A', 6), _row('B', 2)]));
      await tester.pumpAndSettle();
      await _enterKeyboardMode(tester);

      await _press(tester, LogicalKeyboardKey.arrowRight, times: 4);
      expect(_focused(), 'catalog(0, 4)');

      await _press(tester, LogicalKeyboardKey.arrowDown);
      expect(_focused(), 'catalog(1, 1)');
    });

    testWidgets('a vertical move reaches a poster the row has not built yet', (
      tester,
    ) async {
      // Only ~5 posters fit in the 800 dp test viewport, so column 9 of the
      // second row is far outside anything the list has laid out while it
      // still sits at offset 0.
      await tester.pumpWidget(_harness([_row('A', 12), _row('B', 12)]));
      await tester.pumpAndSettle();
      await _enterKeyboardMode(tester);

      await _press(tester, LogicalKeyboardKey.arrowRight, times: 9);
      expect(_focused(), 'catalog(0, 9)');

      await _press(tester, LogicalKeyboardKey.arrowDown);
      expect(
        _focused(),
        'catalog(1, 9)',
        reason:
            'the coordinator must scroll the target row to the column '
            'and claim focus once the poster exists',
      );
      expect(find.text('B 9'), findsOneWidget);
    });

    testWidgets('coming back from search puts focus on the poster the '
        'keyboard left', (tester) async {
      final rows = [_row('A', 6), _row('B', 6)];
      await tester.pumpWidget(_harness(rows));
      await tester.pumpAndSettle();
      await _enterKeyboardMode(tester);
      await _press(tester, LogicalKeyboardKey.arrowRight, times: 2);
      await _press(tester, LogicalKeyboardKey.arrowDown);
      expect(_focused(), 'catalog(1, 2)');

      // Search takes over: the catalog goes unfocusable.
      await tester.pumpWidget(_harness(rows, enabled: false));
      await tester.pumpAndSettle();
      expect(_focused(), isNot('catalog(1, 2)'));

      await tester.pumpWidget(_harness(rows));
      await tester.pumpAndSettle();

      expect(
        _focused(),
        'catalog(1, 2)',
        reason:
            'without this the user pays two dead arrow presses to get '
            'back into the grid every time they close the search',
      );
    });

    testWidgets('the row leaves enough slack for the focus zoom', (
      tester,
    ) async {
      await tester.pumpWidget(_harness([_row('A', 6)]));
      await tester.pumpAndSettle();

      final card = tester.getRect(find.byType(MovieCard).first);
      final viewport = tester.getRect(find.byType(ListView).first);
      // The zoom is painted, not laid out, so the card grows around its
      // own centre by this much on each side.
      const zoom = 1.06;
      final overflow = card.height * (zoom - 1) / 2;

      expect(
        card.top - overflow,
        greaterThanOrEqualTo(viewport.top),
        reason:
            'a focused poster would be cropped at the top of the row — '
            'raise CatalogRowWidget._rowHeight',
      );
      expect(
        card.bottom + overflow,
        lessThanOrEqualTo(viewport.bottom),
        reason: 'a focused poster would be cropped at the bottom of the row',
      );
    });

    testWidgets('running off the end of a row leaves focus alone', (
      tester,
    ) async {
      await tester.pumpWidget(_harness([_row('A', 3)]));
      await tester.pumpAndSettle();
      await _enterKeyboardMode(tester);

      await _press(tester, LogicalKeyboardKey.arrowLeft);
      expect(
        _focused(),
        'catalog(0, 0)',
        reason:
            'nothing sits to the left of the catalog in this harness, so '
            'the fallback traversal has nowhere to go',
      );

      await _press(tester, LogicalKeyboardKey.arrowRight, times: 5);
      expect(_focused(), 'catalog(0, 2)');
    });
  });
}
