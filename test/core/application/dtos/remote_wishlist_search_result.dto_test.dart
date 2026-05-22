import 'package:flutter_test/flutter_test.dart';
import 'package:kidflix/core/application/dtos/remote_wishlist_search_result.dto.dart';
import 'package:kidflix/core/domain/model/wishlist_entry.dart';

Map<String, dynamic> _moviePayload() => {
  'tmdb_id': 22,
  'kind': 'movie',
  'title': 'Pirates des Caraïbes',
  'year': 2003,
  'poster_url': 'https://image.tmdb.org/t/p/w500/poster.jpg',
  'available_in_catalog': false,
  'catalog_kind': null,
  'catalog_id': null,
  'already_in_wishlist': false,
};

Map<String, dynamic> _seriesPayload() => {
  'tmdb_id': 1399,
  'kind': 'series',
  'title': 'Game of Thrones',
  'year': 2011,
  'poster_url': null,
  'available_in_catalog': true,
  'catalog_kind': 'series',
  'catalog_id': 'got',
  'already_in_wishlist': true,
};

void main() {
  group('RemoteWishlistSearchResultDto.fromJson', () {
    test('parses a movie result not yet in the wishlist', () {
      final r = RemoteWishlistSearchResultDto.fromJson(
        _moviePayload(),
      ).toDomain();

      expect(r.tmdbId, 22);
      expect(r.kind, WishlistItemKind.movie);
      expect(r.title, 'Pirates des Caraïbes');
      expect(r.year, 2003);
      expect(r.posterUrl, 'https://image.tmdb.org/t/p/w500/poster.jpg');
      expect(r.availableInCatalog, isFalse);
      expect(r.catalogId, isNull);
      expect(r.alreadyInWishlist, isFalse);
    });

    test('parses a series result already in the wishlist and catalog', () {
      final r = RemoteWishlistSearchResultDto.fromJson(
        _seriesPayload(),
      ).toDomain();

      expect(r.tmdbId, 1399);
      expect(r.kind, WishlistItemKind.series);
      expect(r.title, 'Game of Thrones');
      expect(r.year, 2011);
      expect(r.posterUrl, isNull);
      expect(r.availableInCatalog, isTrue);
      expect(r.catalogId, 'got');
      expect(r.alreadyInWishlist, isTrue);
    });

    test('throws on unknown kind', () {
      final payload = _moviePayload()..['kind'] = 'podcast';
      expect(
        () => RemoteWishlistSearchResultDto.fromJson(payload),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('wishlistKindToWire', () {
    test('round-trips both kinds', () {
      expect(wishlistKindToWire(WishlistItemKind.movie), 'movie');
      expect(wishlistKindToWire(WishlistItemKind.series), 'series');
    });
  });
}
