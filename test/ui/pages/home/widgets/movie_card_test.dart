import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kidflix/core/application/dtos/movie.dto.dart';
import 'package:kidflix/ui/pages/home/widgets/movie_card.widget.dart';

Widget _harness(Widget child) => MaterialApp(
  home: Scaffold(body: SizedBox(height: 300, child: child)),
);

void main() {
  group('MovieCard', () {
    testWidgets('renders title and year · duration caption', (tester) async {
      const dto = MovieDto(
        id: 'm',
        title: 'Astérix',
        year: 2023,
        duration: Duration(minutes: 112),
        posterUrl: null,
      );
      await tester.pumpWidget(
        _harness(MovieCard(movie: dto, onTap: () {})),
      );
      expect(find.text('Astérix'), findsOneWidget);
      expect(find.text('2023 · 1h52'), findsOneWidget);
    });

    testWidgets('caption shows duration only when year is null', (tester) async {
      const dto = MovieDto(
        id: 'm',
        title: 'Inconnu',
        duration: Duration(minutes: 92),
      );
      await tester.pumpWidget(
        _harness(MovieCard(movie: dto, onTap: () {})),
      );
      expect(find.text('1h32'), findsOneWidget);
      expect(find.textContaining('·'), findsNothing);
    });

    testWidgets('tap invokes onTap callback', (tester) async {
      var taps = 0;
      const dto = MovieDto(
        id: 'm',
        title: 'T',
        duration: Duration(minutes: 80),
      );
      await tester.pumpWidget(
        _harness(MovieCard(movie: dto, onTap: () => taps++)),
      );
      await tester.tap(find.byType(MovieCard));
      expect(taps, 1);
    });

    testWidgets('shows fallback when posterUrl is null', (tester) async {
      const dto = MovieDto(
        id: 'm',
        title: 'T',
        duration: Duration(minutes: 80),
      );
      await tester.pumpWidget(
        _harness(MovieCard(movie: dto, onTap: () {})),
      );
      expect(find.byIcon(Icons.movie_outlined), findsOneWidget);
    });
  });
}
