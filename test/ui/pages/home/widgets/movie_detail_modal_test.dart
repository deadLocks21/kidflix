import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kidflix/core/application/dtos/movie.dto.dart';
import 'package:kidflix/core/domain/model/movie.dart';
import 'package:kidflix/core/domain/model/profile.dart';
import 'package:kidflix/ui/pages/home/widgets/movie_detail_modal.widget.dart';

MovieDetailDto _detailWith({
  String title = 'Astérix',
  String? originalTitle,
  String? tagline = 'Il était une fois…',
  int? year = 2023,
  Duration duration = const Duration(minutes: 112),
  List<String> genres = const ['Familial', 'Comédie'],
  List<String> director = const ['Guillaume Canet'],
  List<CastMember> cast = const [],
}) {
  final domain = Movie(
    id: 'm',
    title: title,
    originalTitle: originalTitle,
    duration: duration,
    synopsis: 'Un synopsis.',
    tagline: tagline,
    year: year,
    ageCategory: AgeCategory.enfant,
    genres: genres,
    director: director,
    cast: cast,
    addedAt: DateTime(2026, 1, 1),
  );
  return MovieDetailDto.fromDomain(domain);
}

Widget _harness(Widget child) =>
    MaterialApp(home: Scaffold(body: SingleChildScrollView(child: child)));

void main() {
  group('MovieDetailContent', () {
    testWidgets('renders title, tagline, synopsis and Play button', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(MovieDetailContent(movie: _detailWith())),
      );
      expect(find.text('Astérix'), findsOneWidget);
      expect(find.text('Il était une fois…'), findsOneWidget);
      expect(find.text('Un synopsis.'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Lire'), findsOneWidget);
    });

    testWidgets('Play button is enabled', (tester) async {
      await tester.pumpWidget(
        _harness(MovieDetailContent(movie: _detailWith())),
      );
      final button =
          tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Lire'));
      expect(button.onPressed, isNotNull);
    });

    testWidgets('meta line contains year, duration and primary genre', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(MovieDetailContent(movie: _detailWith())),
      );
      expect(find.text('2023 · 1h52 · Familial'), findsOneWidget);
    });

    testWidgets('originalTitle is not shown when equal to title', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(
          MovieDetailContent(
            movie: _detailWith(title: 'Astérix', originalTitle: 'Astérix'),
          ),
        ),
      );
      // Only one instance of the title (no secondary line).
      expect(find.text('Astérix'), findsOneWidget);
    });

    testWidgets('cast list is capped at 5 by the DTO factory', (tester) async {
      final cast = List.generate(
        9,
        (i) => CastMember(name: 'Actor $i', role: 'Role $i'),
      );
      await tester.pumpWidget(
        _harness(MovieDetailContent(movie: _detailWith(cast: cast))),
      );
      expect(find.textContaining('Actor 0 — Role 0'), findsOneWidget);
      expect(find.textContaining('Actor 4 — Role 4'), findsOneWidget);
      expect(find.textContaining('Actor 5 — Role 5'), findsNothing);
      expect(find.textContaining('Actor 8 — Role 8'), findsNothing);
    });
  });
}
