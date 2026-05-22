import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kidflix/core/application/dtos/movie.dto.dart';
import 'package:kidflix/ui/pages/home/widgets/search_result_tile.widget.dart';

Widget _hostOf(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('SearchResultTile', () {
    testWidgets('renders title and year · duration caption', (tester) async {
      const movie = MovieDto(
        id: 'totoro',
        title: 'Totoro',
        year: 1988,
        duration: Duration(minutes: 86),
        ageCategory: 'enfant',
      );
      await tester.pumpWidget(
        _hostOf(SearchResultTile(item: movie, onTap: () {})),
      );
      expect(find.text('Totoro'), findsOneWidget);
      expect(find.text('1988 · 1h26'), findsOneWidget);
    });

    testWidgets('caption shows duration only when year is null', (
      tester,
    ) async {
      const movie = MovieDto(
        id: 'x',
        title: 'Sans année',
        duration: Duration(minutes: 42),
        ageCategory: 'enfant',
      );
      await tester.pumpWidget(
        _hostOf(SearchResultTile(item: movie, onTap: () {})),
      );
      expect(find.text('42 min'), findsOneWidget);
    });

    testWidgets('tap triggers onTap callback', (tester) async {
      var taps = 0;
      const movie = MovieDto(
        id: 'x',
        title: 'X',
        year: 2020,
        duration: Duration(minutes: 90),
        ageCategory: 'enfant',
      );
      await tester.pumpWidget(
        _hostOf(SearchResultTile(item: movie, onTap: () => taps += 1)),
      );
      await tester.tap(find.byType(InkWell));
      await tester.pump();
      expect(taps, 1);
    });

    testWidgets('renders chevron icon', (tester) async {
      const movie = MovieDto(
        id: 'x',
        title: 'X',
        duration: Duration(minutes: 90),
        ageCategory: 'enfant',
      );
      await tester.pumpWidget(
        _hostOf(SearchResultTile(item: movie, onTap: () {})),
      );
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    });
  });
}
