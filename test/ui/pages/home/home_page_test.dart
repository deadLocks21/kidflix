import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kidflix/core/application/dtos/catalog_row.dto.dart';
import 'package:kidflix/core/application/dtos/movie.dto.dart';
import 'package:kidflix/infrastructure/providers/catalog.usecases_provider.dart';
import 'package:kidflix/ui/pages/home/home.page.dart';
import 'package:kidflix/ui/pages/home/widgets/catalog_row.widget.dart';
import 'package:kidflix/ui/pages/home/widgets/catalog_skeleton.widget.dart';
import 'package:kidflix/ui/pages/home/widgets/home_profile_menu.widget.dart';

Widget _app(List<Object> overrides) => ProviderScope(
  overrides: overrides.cast(),
  child: const MaterialApp(home: HomePage()),
);

const _movie = MovieDto(
  id: 'm1',
  title: 'Astérix',
  year: 2023,
  duration: Duration(minutes: 112),
  ageCategory: 'enfant',
);

const _row = CatalogRowDto(
  label: 'Récemment ajoutés',
  type: 'recentlyAdded',
  items: [_movie],
);

void main() {
  group('HomePage', () {
    testWidgets('shows skeleton while loading', (tester) async {
      final pending = Completer<List<CatalogRowDto>>();
      await tester.pumpWidget(
        _app([
          homeCatalogRowsProvider.overrideWith((ref) => pending.future),
        ]),
      );
      expect(find.byType(CatalogSkeleton), findsOneWidget);
    });

    testWidgets('shows empty state when rows list is empty', (tester) async {
      await tester.pumpWidget(
        _app([
          homeCatalogRowsProvider.overrideWith((ref) async => const []),
        ]),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Aucun film disponible pour ce profil pour le moment.'),
        findsOneWidget,
      );
    });

    testWidgets('shows rows when data is available', (tester) async {
      await tester.pumpWidget(
        _app([
          homeCatalogRowsProvider.overrideWith((ref) async => const [_row]),
        ]),
      );
      await tester.pumpAndSettle();
      expect(find.byType(CatalogRowWidget), findsOneWidget);
      expect(find.text('Récemment ajoutés'), findsOneWidget);
    });

    testWidgets('shows retry button on error', (tester) async {
      await tester.pumpWidget(
        _app([
          homeCatalogRowsProvider.overrideWith(
            (ref) => Future.error(StateError('boom')),
          ),
        ]),
      );
      await tester.pumpAndSettle();
      expect(find.text('Réessayer'), findsOneWidget);
    });

    testWidgets('always shows the profile menu action', (tester) async {
      await tester.pumpWidget(
        _app([
          homeCatalogRowsProvider.overrideWith((ref) async => const [_row]),
        ]),
      );
      await tester.pumpAndSettle();
      expect(find.byType(HomeProfileMenu), findsOneWidget);
    });

    testWidgets('shows search icon in normal mode', (tester) async {
      await tester.pumpWidget(
        _app([
          homeCatalogRowsProvider.overrideWith((ref) async => const [_row]),
        ]),
      );
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.search), findsOneWidget);
    });

    testWidgets('tapping search icon swaps AppBar into search mode', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app([
          homeCatalogRowsProvider.overrideWith((ref) async => const [_row]),
        ]),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.search));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsOneWidget);
      expect(find.byIcon(Icons.close), findsOneWidget);
      expect(find.byType(HomeProfileMenu), findsNothing);
      expect(
        find.text('Tape au moins 2 lettres pour chercher.'),
        findsOneWidget,
      );
    });

    testWidgets('closing search returns to normal mode with rows visible', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app([
          homeCatalogRowsProvider.overrideWith((ref) async => const [_row]),
        ]),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.search));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
      expect(find.byType(HomeProfileMenu), findsOneWidget);
      expect(find.byIcon(Icons.search), findsOneWidget);
      expect(find.byType(CatalogRowWidget), findsOneWidget);
    });
  });
}
