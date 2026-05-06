import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kidflix/core/application/dtos/series.dto.dart';
import 'package:kidflix/ui/pages/home/widgets/series_card.widget.dart';

Widget _harness(Widget child) => MaterialApp(
  home: Scaffold(body: SizedBox(height: 300, child: child)),
);

const _dto = SeriesDto(
  id: 's',
  title: 'Pingu',
  year: 2010,
  posterUrl: null,
  ageCategory: 'enfant',
  seasonsCount: 2,
  episodesCount: 24,
);

void main() {
  group('SeriesCard', () {
    testWidgets('no progress bar by default', (tester) async {
      await tester.pumpWidget(_harness(const SeriesCard(series: _dto)));
      expect(find.byType(LinearProgressIndicator), findsNothing);
    });

    testWidgets('no bar when progress is 0', (tester) async {
      await tester.pumpWidget(
        _harness(const SeriesCard(series: _dto, progress: 0)),
      );
      expect(find.byType(LinearProgressIndicator), findsNothing);
    });

    testWidgets('renders bar with provided progress value', (tester) async {
      await tester.pumpWidget(
        _harness(const SeriesCard(series: _dto, progress: 0.42)),
      );
      final bar = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(bar.value, 0.42);
    });
  });
}
