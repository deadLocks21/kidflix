import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kidflix/core/application/dtos/movie.dto.dart';
import 'package:kidflix/infrastructure/providers/search.controller_provider.dart';
import 'package:kidflix/infrastructure/providers/search.usecase_provider.dart';
import 'package:kidflix/ui/pages/home/widgets/search_result_tile.widget.dart';
import 'package:kidflix/ui/pages/home/widgets/search_results.widget.dart';

Widget _app(List<Object> overrides) => ProviderScope(
  overrides: overrides.cast(),
  child: const MaterialApp(home: Scaffold(body: SearchResults())),
);

const _movieA = MovieDto(
  id: 'a',
  title: 'Astérix',
  year: 2023,
  duration: Duration(minutes: 112),
  ageCategory: 'enfant',
);

const _movieB = MovieDto(
  id: 'b',
  title: 'Totoro',
  year: 1988,
  duration: Duration(minutes: 86),
  ageCategory: 'enfant',
);

/// Pumps long enough for the controller's 250 ms debounce to flush.
Future<void> _flushDebounce(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  group('SearchResults', () {
    testWidgets('below-minimum state when debounced query is empty', (
      tester,
    ) async {
      await tester.pumpWidget(_app(const []));
      expect(
        find.text('Tape au moins 2 lettres pour chercher.'),
        findsOneWidget,
      );
    });

    testWidgets('below-minimum state when query is 1 character', (
      tester,
    ) async {
      await tester.pumpWidget(_app(const []));
      final container = ProviderScope.containerOf(
        tester.element(find.byType(SearchResults)),
      );
      container.read(searchUiControllerProvider.notifier).updateQuery('t');
      await _flushDebounce(tester);
      expect(
        find.text('Tape au moins 2 lettres pour chercher.'),
        findsOneWidget,
      );
    });

    testWidgets('loading state shows spinner', (tester) async {
      final pending = Completer<List<MovieDto>>();
      await tester.pumpWidget(
        _app([
          searchResultsProvider.overrideWith((ref, q) => pending.future),
        ]),
      );
      final container = ProviderScope.containerOf(
        tester.element(find.byType(SearchResults)),
      );
      container.read(searchUiControllerProvider.notifier).updateQuery('tot');
      await _flushDebounce(tester);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('no-results state shows message with the query', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app([
          searchResultsProvider.overrideWith((ref, q) async => const []),
        ]),
      );
      final container = ProviderScope.containerOf(
        tester.element(find.byType(SearchResults)),
      );
      container.read(searchUiControllerProvider.notifier).updateQuery('xyz');
      await _flushDebounce(tester);
      await tester.pumpAndSettle();
      expect(
        find.text('Aucun résultat ne correspond à « xyz ».'),
        findsOneWidget,
      );
    });

    testWidgets('results state renders a tile per movie', (tester) async {
      await tester.pumpWidget(
        _app([
          searchResultsProvider.overrideWith(
            (ref, q) async => const [_movieA, _movieB],
          ),
        ]),
      );
      final container = ProviderScope.containerOf(
        tester.element(find.byType(SearchResults)),
      );
      container.read(searchUiControllerProvider.notifier).updateQuery('tot');
      await _flushDebounce(tester);
      await tester.pumpAndSettle();
      expect(find.byType(SearchResultTile), findsNWidgets(2));
      expect(find.text('Astérix'), findsOneWidget);
      expect(find.text('Totoro'), findsOneWidget);
    });

    testWidgets('error state exposes a retry button', (tester) async {
      await tester.pumpWidget(
        _app([
          searchResultsProvider.overrideWith(
            (ref, q) => Future.error(StateError('boom')),
          ),
        ]),
      );
      final container = ProviderScope.containerOf(
        tester.element(find.byType(SearchResults)),
      );
      container.read(searchUiControllerProvider.notifier).updateQuery('tot');
      await _flushDebounce(tester);
      await tester.pumpAndSettle();
      expect(find.text('Impossible de lancer la recherche.'), findsOneWidget);
      expect(find.text('Réessayer'), findsOneWidget);
    });
  });
}
