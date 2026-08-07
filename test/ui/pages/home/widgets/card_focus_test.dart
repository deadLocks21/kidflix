import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kidflix/core/application/dtos/movie.dto.dart';
import 'package:kidflix/ui/focus/keyboard_mode.dart';
import 'package:kidflix/ui/focus/kidflix_focus_ring.widget.dart';
import 'package:kidflix/ui/pages/home/widgets/movie_card.widget.dart';
import 'package:kidflix/ui/theme/app_theme_data.dart';

const _movie = MovieDto(
  id: 'm',
  title: 'Percy Jackson et les Olympiens',
  year: 2023,
  duration: Duration(minutes: 112),
  ageCategory: 'enfant',
);

Widget _harness() => MaterialApp(
  theme: AppThemeData.buildDarkTheme(),
  builder: (context, child) =>
      KeyboardModeScope(child: child ?? const SizedBox.shrink()),
  home: Scaffold(
    body: Center(
      child: MovieCard(movie: _movie, onTap: () {}, autofocus: true),
    ),
  ),
);

Future<void> _focusWithKeyboard(WidgetTester tester) async {
  // The first press only reveals the ring ; focus is already placed.
  await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
  await tester.pumpAndSettle();
}

Color? _captionColour(WidgetTester tester) {
  final style = tester
      .widget<AnimatedDefaultTextStyle>(
        find
            .ancestor(
              of: find.text('2023 · 1h52'),
              matching: find.byType(AnimatedDefaultTextStyle),
            )
            .first,
      )
      .style;
  return style.color;
}

void main() {
  group('catalog card focus', () {
    testWidgets('no ink wash bleeds behind the title strip', (tester) async {
      await tester.pumpWidget(_harness());
      await tester.pumpAndSettle();
      await _focusWithKeyboard(tester);

      final inkWell = tester.widget<InkWell>(find.byType(InkWell).first);
      expect(
        inkWell.focusColor,
        Colors.transparent,
        reason:
            'the ink highlight paints behind the child, so an opaque '
            'poster hides it and the caption does not — it showed up as a '
            'grey slab under the title',
      );
    });

    testWidgets('the ring frames the poster, not the caption', (tester) async {
      await tester.pumpWidget(_harness());
      await tester.pumpAndSettle();
      await _focusWithKeyboard(tester);

      final ring = tester.getSize(find.byType(KidflixFocusRing));
      final card = tester.getSize(find.byType(MovieCard));

      expect(ring.height, MovieCard.posterHeight);
      expect(
        ring.height,
        lessThan(card.height),
        reason:
            'a ring around the whole card runs through text that starts '
            'flush against its edge',
      );
    });

    testWidgets('the caption brightens on the selected card', (tester) async {
      await tester.pumpWidget(_harness());
      await tester.pumpAndSettle();
      final scheme = AppThemeData.buildDarkTheme().colorScheme;

      expect(_captionColour(tester), scheme.onSurfaceVariant);

      await _focusWithKeyboard(tester);

      expect(
        _captionColour(tester),
        scheme.onSurface,
        reason:
            'what makes the tile come forward rather than just its '
            'outline',
      );
    });
  });
}
