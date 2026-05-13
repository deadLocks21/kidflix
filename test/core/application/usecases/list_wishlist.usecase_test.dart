import 'package:flutter_test/flutter_test.dart';
import 'package:kidflix/core/application/usecases/list_wishlist.usecase.dart';
import 'package:kidflix/core/domain/model/wishlist_entry.dart';
import 'package:kidflix/core/domain/model/wishlist_search_result.dart';
import 'package:kidflix/core/domain/services/wishlist.repository.dart';

class _StubRepository implements WishlistRepository {
  final List<WishlistEntry> _seed;
  _StubRepository(this._seed);

  @override
  Future<List<WishlistEntry>> list() async => List.of(_seed);

  @override
  Future<WishlistEntry> updateStatus({
    required int watcharrId,
    required WatchedStatus status,
  }) =>
      throw UnimplementedError();

  @override
  Future<void> remove(int watcharrId) => throw UnimplementedError();

  @override
  Future<List<WishlistSearchResult>> search(String query) =>
      throw UnimplementedError();

  @override
  Future<WishlistEntry> add({
    required int tmdbId,
    required WishlistItemKind kind,
  }) =>
      throw UnimplementedError();
}

WishlistEntry _entry({
  required int watcharrId,
  required String title,
  WishlistItemKind kind = WishlistItemKind.movie,
  WatchedStatus status = WatchedStatus.planned,
  bool available = false,
}) =>
    WishlistEntry(
      watcharrId: watcharrId,
      tmdbId: 1000 + watcharrId,
      kind: kind,
      title: title,
      status: status,
      rating: 0,
      availableInCatalog: available,
      catalogId: available ? 'catalog-$watcharrId' : null,
    );

void main() {
  group('ListWishlistUseCase.execute', () {
    test('returns an empty list when the repository is empty', () async {
      final usecase = ListWishlistUseCase(_StubRepository(const []));
      final result = await usecase.execute();
      expect(result, isEmpty);
    });

    test('keeps planned movies AND planned series not in the catalog',
        () async {
      final entries = [
        _entry(watcharrId: 1, title: 'Keeper Movie'),
        _entry(
          watcharrId: 2,
          title: 'Keeper Series',
          kind: WishlistItemKind.series,
        ),
        _entry(
          watcharrId: 3,
          title: 'Available — filtered out',
          available: true,
        ),
        _entry(
          watcharrId: 4,
          title: 'Available series — filtered out',
          kind: WishlistItemKind.series,
          available: true,
        ),
        _entry(
          watcharrId: 5,
          title: 'Watching — filtered out',
          status: WatchedStatus.watching,
        ),
        _entry(
          watcharrId: 6,
          title: 'Finished — filtered out',
          status: WatchedStatus.finished,
        ),
        _entry(
          watcharrId: 7,
          title: 'Hold — filtered out',
          status: WatchedStatus.hold,
        ),
        _entry(
          watcharrId: 8,
          title: 'Dropped — filtered out',
          status: WatchedStatus.dropped,
        ),
      ];
      final usecase = ListWishlistUseCase(_StubRepository(entries));
      final result = await usecase.execute();
      expect(result.map((e) => e.title), ['Keeper Movie', 'Keeper Series']);
    });

    test('returns empty when nothing matches the filter', () async {
      final entries = [
        _entry(
          watcharrId: 1,
          title: 'Already in catalog',
          available: true,
        ),
        _entry(
          watcharrId: 2,
          title: 'Already finished',
          status: WatchedStatus.finished,
        ),
        _entry(
          watcharrId: 3,
          title: 'Series already in catalog',
          kind: WishlistItemKind.series,
          available: true,
        ),
      ];
      final usecase = ListWishlistUseCase(_StubRepository(entries));
      final result = await usecase.execute();
      expect(result, isEmpty);
    });

    test('sorts the survivors alphabetically (case-insensitive)', () async {
      final entries = [
        _entry(watcharrId: 1, title: 'Zorro'),
        _entry(watcharrId: 2, title: 'abeille'),
        _entry(watcharrId: 3, title: 'Manchot'),
      ];
      final usecase = ListWishlistUseCase(_StubRepository(entries));
      final result = await usecase.execute();
      expect(result.map((e) => e.title), ['abeille', 'Manchot', 'Zorro']);
    });
  });
}
