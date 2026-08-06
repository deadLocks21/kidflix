import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kidflix/core/domain/model/media.dart';
import 'package:kidflix/core/domain/model/profile.dart';
import 'package:kidflix/ui/focus/keyboard_mode.dart';
import 'package:kidflix/ui/pages/home/widgets/download_progress_button.widget.dart';
import 'package:kidflix/ui/pages/home/widgets/series_detail_modal.widget.dart';
import 'package:kidflix/ui/theme/app_theme_data.dart';

Episode _ep(int n) => Episode(
  id: 's1e$n',
  seriesId: 'pingu',
  seasonNumber: 1,
  episodeNumber: n,
  title: 'Épisode $n',
  duration: const Duration(minutes: 5),
  ageCategory: AgeCategory.enfant,
  addedAt: DateTime(2026, 5, 1),
);

/// Seasons are supplied inline so the modal never reaches for the network.
Series _series() {
  final season = Season(seasonNumber: 1, episodes: [_ep(1), _ep(2)]);
  return Series(
    id: 'pingu',
    title: 'Pingu',
    synopsis: '',
    ageCategory: AgeCategory.enfant,
    genres: const [],
    director: const [],
    cast: const [],
    addedAt: DateTime(2026, 5, 1),
    seasonsCount: 1,
    episodesCount: season.episodes.length,
    seasons: [season],
  );
}

Widget _harness() => ProviderScope(
  child: MaterialApp(
    theme: AppThemeData.buildDarkTheme(),
    builder: (context, child) =>
        KeyboardModeScope(child: child ?? const SizedBox.shrink()),
    home: Scaffold(body: SeriesDetailContent(catalogSeries: _series())),
  ),
);

/// `DownloadIntentButton` keeps a one-second periodic timer alive, so
/// `pumpAndSettle` would never return here.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _press(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyEvent(key);
  await _settle(tester);
}

/// The episode rows' own buttons, matched on their tooltip: both are
/// icon-only, and the header's play button carries a label instead.
Finder _play(int index) => find
    .byWidgetPredicate((w) => w is IconButton && w.tooltip == 'Lire')
    .at(index);

Finder _download(int index) => find
    .byWidgetPredicate((w) => w is IconButton && w.tooltip == 'Télécharger')
    .at(index);

/// Whether the primary focus sits *inside* [button] — the button's node
/// lives below it, so looking upwards from the button would find the
/// wrong one.
bool _holdsFocus(WidgetTester tester, Finder button) {
  final focused = FocusManager.instance.primaryFocus?.context;
  if (focused == null) return false;
  final target = tester.element(button);
  var found = false;
  focused.visitAncestorElements((element) {
    if (element != target) return true;
    found = true;
    return false;
  });
  return found;
}

/// Walks the tab order until [button] takes focus, the way a keyboard
/// user reaches it from the top of the modal.
Future<void> _tabUntil(WidgetTester tester, Finder button) async {
  for (var i = 0; i < 20; i++) {
    if (_holdsFocus(tester, button)) return;
    await _press(tester, LogicalKeyboardKey.tab);
  }
  fail('never reached the requested button through the tab order');
}

void main() {
  group('episode row focus', () {
    testWidgets('the row is clickable but never a keyboard stop', (
      tester,
    ) async {
      await tester.pumpWidget(_harness());
      await _settle(tester);

      // The tap lives on a GestureDetector wrapping the tile, so the tile
      // itself is inert — unlike the season header above it, which stays a
      // genuine ListTile action.
      final row = tester.widget<ListTile>(
        find
            .ancestor(
              of: find.text('E1 · Épisode 1'),
              matching: find.byType(ListTile),
            )
            .first,
      );
      expect(row.onTap, isNull);
      expect(
        find.ancestor(
          of: find.text('E1 · Épisode 1'),
          matching: find.byType(GestureDetector),
        ),
        findsWidgets,
        reason: 'clicking anywhere on the row must still play the episode',
      );
      expect(
        _play(0),
        findsOneWidget,
        reason: 'icon-only, so the tooltip carries the meaning',
      );

      await _tabUntil(tester, _play(0));
      await _press(tester, LogicalKeyboardKey.tab);
      expect(_holdsFocus(tester, _download(0)), isTrue);

      await _press(tester, LogicalKeyboardKey.tab);
      expect(
        _holdsFocus(tester, _play(1)),
        isTrue,
        reason:
            'no stop on the row itself in between — one visual element '
            'per action, one focus stop per action',
      );
    });

    testWidgets('right and left move between Lire and Télécharger', (
      tester,
    ) async {
      await tester.pumpWidget(_harness());
      await _settle(tester);
      await _tabUntil(tester, _play(0));

      await _press(tester, LogicalKeyboardKey.arrowRight);
      expect(
        _holdsFocus(tester, _download(0)),
        isTrue,
        reason: 'this is the move that used to need Tab',
      );

      await _press(tester, LogicalKeyboardKey.arrowLeft);
      expect(_holdsFocus(tester, _play(0)), isTrue);
    });

    testWidgets('right of Télécharger stays put instead of escaping to the '
        'close button', (tester) async {
      await tester.pumpWidget(_harness());
      await _settle(tester);
      await _tabUntil(tester, _play(0));
      await _press(tester, LogicalKeyboardKey.arrowRight);
      expect(_holdsFocus(tester, _download(0)), isTrue);

      await _press(tester, LogicalKeyboardKey.arrowRight);

      expect(
        _holdsFocus(tester, _download(0)),
        isTrue,
        reason:
            'the sheet close button sticks out further right and is '
            'scrolled off the top by then — landing there reads as losing '
            'the focus altogether',
      );
    });

    testWidgets('the download button keeps one width across its states', (
      tester,
    ) async {
      await tester.pumpWidget(_harness());
      await _settle(tester);
      final idle = tester.getSize(_download(0)).width;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppThemeData.buildDarkTheme(),
            home: const Scaffold(
              body: Center(
                child: DownloadProgressButton(
                  bytesReceived: 5 * 1024 * 1024,
                  bytesTotal: 20 * 1024 * 1024,
                  compact: true,
                ),
              ),
            ),
          ),
        ),
      );
      await _settle(tester);
      final inFlight = tester.getSize(find.byType(IconButton)).width;

      expect(
        inFlight,
        idle,
        reason:
            'a button that resizes as a download starts shoves its '
            'neighbour sideways mid-row',
      );
    });

    testWidgets('down stays in the same column of buttons', (tester) async {
      await tester.pumpWidget(_harness());
      await _settle(tester);
      await _tabUntil(tester, _play(0));

      await _press(tester, LogicalKeyboardKey.arrowDown);

      expect(_holdsFocus(tester, _play(1)), isTrue);
    });
  });
}
