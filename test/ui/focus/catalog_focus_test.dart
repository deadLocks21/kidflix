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

final _appBarAction = FocusNode(debugLabel: 'appbar:profil');

/// Mirrors the home page: the scope sits *above* the [Scaffold] so it
/// covers the app bar, and only the body is excluded while searching.
/// Same cache extent and same row widget too — only the data is faked.
Widget _harness(
  List<CatalogRowDto> rows, {
  bool enabled = true,
  bool withAppBar = false,
}) => MaterialApp(
  theme: AppThemeData.buildDarkTheme(),
  builder: (context, child) =>
      KeyboardModeScope(child: child ?? const SizedBox.shrink()),
  home: CatalogFocusScope(
    enabled: enabled,
    child: Scaffold(
      appBar: withAppBar
          ? AppBar(
              title: const Text('Kidflix'),
              actions: [
                IconButton(
                  focusNode: _appBarAction,
                  icon: const Icon(Icons.person),
                  onPressed: () {},
                ),
              ],
            )
          : null,
      body: ExcludeFocus(
        excluding: !enabled,
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

    testWidgets('the end of a short row holds focus, it does not spill into '
        'the longer row below', (tester) async {
      // Row 0 ends at column 1 ; row 1 keeps going. Everything from
      // (1, 2) onwards sits to the *right* of (0, 1) on screen, so the
      // framework's own directional traversal would happily jump there.
      await tester.pumpWidget(_harness([_row('A', 2), _row('B', 8)]));
      await tester.pumpAndSettle();
      await _enterKeyboardMode(tester);

      await _press(tester, LogicalKeyboardKey.arrowRight);
      expect(_focused(), 'catalog(0, 1)');

      await _press(tester, LogicalKeyboardKey.arrowRight, times: 3);
      expect(
        _focused(),
        'catalog(0, 1)',
        reason:
            'past the last poster of a row the key is absorbed — focus '
            'must not walk sideways into another row',
      );
    });

    testWidgets('coming down from the app bar lands in the catalog, not in '
        'whatever row happens to sit under the button', (tester) async {
      // A first row that stops well short of the right edge is what makes
      // the framework's own guess go wrong: nothing of row 0 sits under
      // the app bar action, so it reaches for the nearest poster in the
      // row below.
      await tester.pumpWidget(
        _harness([_row('A', 3), _row('B', 12)], withAppBar: true),
      );
      await tester.pumpAndSettle();
      await _enterKeyboardMode(tester);
      expect(_focused(), 'catalog(0, 0)');

      _appBarAction.requestFocus();
      await tester.pumpAndSettle();
      expect(_focused(), 'appbar:profil');

      await _press(tester, LogicalKeyboardKey.arrowDown);

      expect(
        _focused(),
        'catalog(0, 0)',
        reason:
            'going back down must return where the catalog was left, '
            'not to the far end of the second row',
      );
    });

    testWidgets('coming down from the app bar returns to the poster the '
        'keyboard left', (tester) async {
      await tester.pumpWidget(
        _harness([_row('A', 8), _row('B', 8)], withAppBar: true),
      );
      await tester.pumpAndSettle();
      await _enterKeyboardMode(tester);
      await _press(tester, LogicalKeyboardKey.arrowRight, times: 3);
      expect(_focused(), 'catalog(0, 3)');

      _appBarAction.requestFocus();
      await tester.pumpAndSettle();
      await _press(tester, LogicalKeyboardKey.arrowDown);

      expect(_focused(), 'catalog(0, 3)');
    });

    testWidgets('the start of a row holds focus too', (tester) async {
      await tester.pumpWidget(_harness([_row('A', 8), _row('B', 3)]));
      await tester.pumpAndSettle();
      await _enterKeyboardMode(tester);

      await _press(tester, LogicalKeyboardKey.arrowDown);
      expect(_focused(), 'catalog(1, 0)');

      await _press(tester, LogicalKeyboardKey.arrowLeft, times: 3);
      expect(_focused(), 'catalog(1, 0)');
    });
  });
}
