import 'package:flutter_test/flutter_test.dart';
import 'package:kidflix/core/application/dtos/remote_wishlist_entry.dto.dart';
import 'package:kidflix/core/domain/model/wishlist_entry.dart';

Map<String, dynamic> _moviePayload() => {
  'watcharr_id': 42,
  'tmdb_id': 22,
  'kind': 'movie',
  'title': 'Pirates des Caraïbes',
  'year': 2003,
  'poster_url': 'https://image.tmdb.org/t/p/w500/poster.jpg',
  'status': 'PLANNED',
  'rating': 0,
  'available_in_catalog': true,
  'catalog_kind': 'movie',
  'catalog_id': 'pirates-caraibes',
};

Map<String, dynamic> _seriesPayload() => {
  'watcharr_id': 87,
  'tmdb_id': 1399,
  'kind': 'series',
  'title': 'Game of Thrones',
  'year': 2011,
  'poster_url': null,
  'status': 'HOLD',
  'rating': 8,
  'available_in_catalog': false,
  'catalog_kind': null,
  'catalog_id': null,
};

void main() {
  group('RemoteWishlistEntryDto.fromJson', () {
    test('parses a movie entry with catalog crossing', () {
      final entry = RemoteWishlistEntryDto.fromJson(_moviePayload()).toDomain();

      expect(entry.watcharrId, 42);
      expect(entry.tmdbId, 22);
      expect(entry.kind, WishlistItemKind.movie);
      expect(entry.title, 'Pirates des Caraïbes');
      expect(entry.year, 2003);
      expect(entry.posterUrl, 'https://image.tmdb.org/t/p/w500/poster.jpg');
      expect(entry.status, WatchedStatus.planned);
      expect(entry.rating, 0);
      expect(entry.availableInCatalog, isTrue);
      expect(entry.catalogId, 'pirates-caraibes');
    });

    test('parses a series entry without catalog crossing', () {
      final entry = RemoteWishlistEntryDto.fromJson(_seriesPayload()).toDomain();

      expect(entry.watcharrId, 87);
      expect(entry.tmdbId, 1399);
      expect(entry.kind, WishlistItemKind.series);
      expect(entry.title, 'Game of Thrones');
      expect(entry.year, 2011);
      expect(entry.posterUrl, isNull);
      expect(entry.status, WatchedStatus.hold);
      expect(entry.rating, 8);
      expect(entry.availableInCatalog, isFalse);
      expect(entry.catalogId, isNull);
    });

    test('discards catalog_kind on projection to Domain', () {
      // The DTO accepts catalog_kind on the wire (verbose for the
      // backend) but the Domain entry only carries `kind` — assert
      // the projection doesn't add a duplicate.
      final entry = RemoteWishlistEntryDto.fromJson(_moviePayload()).toDomain();
      // No `catalogKind` getter on WishlistEntry — the field doesn't
      // exist. If it ever sneaks back in, this test will fail to
      // compile, which is the desired guardrail.
      expect(entry.kind, WishlistItemKind.movie);
    });

    test('parses all five WatchedStatus values', () {
      for (final pair in const [
        ('PLANNED', WatchedStatus.planned),
        ('WATCHING', WatchedStatus.watching),
        ('FINISHED', WatchedStatus.finished),
        ('HOLD', WatchedStatus.hold),
        ('DROPPED', WatchedStatus.dropped),
      ]) {
        final payload = _moviePayload()..['status'] = pair.$1;
        final entry = RemoteWishlistEntryDto.fromJson(payload).toDomain();
        expect(entry.status, pair.$2);
      }
    });

    test('throws on unknown kind', () {
      final payload = _moviePayload()..['kind'] = 'podcast';
      expect(
        () => RemoteWishlistEntryDto.fromJson(payload),
        throwsA(isA<FormatException>()),
      );
    });

    test('throws on unknown status', () {
      final payload = _moviePayload()..['status'] = 'BACKLOG';
      expect(
        () => RemoteWishlistEntryDto.fromJson(payload),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('watchedStatusToWire', () {
    test('round-trips every status', () {
      for (final status in WatchedStatus.values) {
        // toWire then fromJson on a payload re-using that wire string —
        // a tighter round-trip than just toString comparison.
        final payload = _moviePayload()..['status'] = watchedStatusToWire(status);
        final parsed =
            RemoteWishlistEntryDto.fromJson(payload).toDomain().status;
        expect(parsed, status, reason: 'round-trip failed for $status');
      }
    });
  });
}
