import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kidflix/core/domain/model/wishlist_entry.dart';
import 'package:kidflix/core/domain/model/wishlist_search_result.dart';
import 'package:kidflix/infrastructure/providers/wishlist.repository_provider.dart';
import 'package:kidflix/infrastructure/wishlist/in_memory.wishlist.repository.dart';
import 'package:kidflix/ui/pages/wishlist/wishlist_search.page.dart';

/// Records every query and answers with a single poster-less hit, so the
/// tile renders without touching the network.
class _RecordingWishlistRepository extends InMemoryWishlistRepository {
  final List<String> queries = [];

  @override
  Future<List<WishlistSearchResult>> search(String query) async {
    queries.add(query);
    return const [
      WishlistSearchResult(
        tmdbId: 302946,
        kind: WishlistItemKind.movie,
        title: 'The Accountant',
        year: 2016,
        availableInCatalog: false,
        alreadyInWishlist: false,
      ),
    ];
  }
}

Widget _app(_RecordingWishlistRepository repo, {String? initialQuery}) =>
    ProviderScope(
      overrides: [wishlistRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp(home: WishlistSearchPage(initialQuery: initialQuery)),
    );

void main() {
  group('WishlistSearchPage', () {
    testWidgets('initialQuery pre-fills the field and runs the search', (
      tester,
    ) async {
      final repo = _RecordingWishlistRepository();
      await tester.pumpWidget(_app(repo, initialQuery: ' the accountant '));
      await tester.pumpAndSettle();

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, 'the accountant');
      expect(field.autofocus, isFalse);
      expect(repo.queries, ['the accountant']);
      expect(find.text('The Accountant'), findsOneWidget);
    });

    testWidgets('without initialQuery the field is empty and focused', (
      tester,
    ) async {
      final repo = _RecordingWishlistRepository();
      await tester.pumpWidget(_app(repo));
      await tester.pumpAndSettle();

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, isEmpty);
      expect(field.autofocus, isTrue);
      expect(repo.queries, isEmpty);
      expect(
        find.text('Tape au moins 2 caractères pour rechercher dans Watcharr.'),
        findsOneWidget,
      );
    });
  });
}
