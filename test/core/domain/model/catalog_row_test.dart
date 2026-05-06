import 'package:flutter_test/flutter_test.dart';
import 'package:kidflix/core/domain/model/catalog_row.dart';

void main() {
  group('CatalogRow', () {
    test('can be constructed with an empty items list', () {
      const row = CatalogRow(
        label: 'Empty',
        type: CatalogRowType.favorites,
        items: [],
      );
      expect(row.items, isEmpty);
    });
  });

  group('CatalogRowType', () {
    test('exposes exactly 7 variants', () {
      expect(CatalogRowType.values.length, 7);
    });

    test('contains the expected variants by name', () {
      final names = CatalogRowType.values.map((e) => e.name).toSet();
      expect(
        names,
        {
          'continueWatching',
          'recentlyAdded',
          'favorites',
          'saga',
          'genre',
          'neverWatched',
          'downloaded',
        },
      );
    });
  });
}
