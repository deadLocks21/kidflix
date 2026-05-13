import 'package:flutter_test/flutter_test.dart';
import 'package:kidflix/core/application/usecases/search_addable_wishlist_content.usecase.dart';
import 'package:kidflix/core/domain/model/wishlist_entry.dart';
import 'package:kidflix/core/domain/model/wishlist_search_result.dart';
import 'package:kidflix/core/domain/services/wishlist.repository.dart';

class _StubRepository implements WishlistRepository {
  final List<WishlistSearchResult> _results;
  int searchCalls = 0;
  String? lastQuery;

  _StubRepository(this._results);

  @override
  Future<List<WishlistSearchResult>> search(String query) async {
    searchCalls++;
    lastQuery = query;
    return _results;
  }

  @override
  Future<List<WishlistEntry>> list() => throw UnimplementedError();

  @override
  Future<WishlistEntry> updateStatus({
    required int watcharrId,
    required WatchedStatus status,
  }) =>
      throw UnimplementedError();

  @override
  Future<void> remove(int watcharrId) => throw UnimplementedError();

  @override
  Future<WishlistEntry> add({
    required int tmdbId,
    required WishlistItemKind kind,
  }) =>
      throw UnimplementedError();
}

WishlistSearchResult _result(int id, {WishlistItemKind kind = WishlistItemKind.movie}) =>
    WishlistSearchResult(
      tmdbId: id,
      kind: kind,
      title: 'Result $id',
      availableInCatalog: false,
      alreadyInWishlist: false,
    );

void main() {
  group('SearchAddableWishlistContentUseCase.execute', () {
    test('short-circuits to empty list when query is empty', () async {
      final repo = _StubRepository([_result(1)]);
      final usecase = SearchAddableWishlistContentUseCase(repo);
      final result = await usecase.execute('');
      expect(result, isEmpty);
      expect(repo.searchCalls, 0);
    });

    test('short-circuits when query length < 2 after trim', () async {
      final repo = _StubRepository([_result(1)]);
      final usecase = SearchAddableWishlistContentUseCase(repo);
      expect(await usecase.execute(' a '), isEmpty);
      expect(await usecase.execute('x'), isEmpty);
      expect(repo.searchCalls, 0);
    });

    test('forwards the trimmed query to the repository', () async {
      final repo = _StubRepository([_result(1), _result(2)]);
      final usecase = SearchAddableWishlistContentUseCase(repo);
      final result = await usecase.execute('  pingu  ');
      expect(repo.lastQuery, 'pingu');
      expect(repo.searchCalls, 1);
      expect(result.length, 2);
      expect(result.first.tmdbId, 1);
    });

    test('preserves the repository result order', () async {
      // The use case doesn't impose any sort — Watcharr's relevance
      // ranking flows through unchanged.
      final repo = _StubRepository([
        _result(3),
        _result(1),
        _result(2),
      ]);
      final usecase = SearchAddableWishlistContentUseCase(repo);
      final result = await usecase.execute('something');
      expect(result.map((r) => r.tmdbId), [3, 1, 2]);
    });
  });
}
