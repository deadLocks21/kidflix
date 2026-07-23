import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kidflix/ui/router/app_router.dart';

void main() {
  group('playerPageKey', () {
    test('two movies produce different keys', () {
      // GoRouter keys its page on the route *pattern*, so without this
      // both of these would be `/player/:movieId` and navigating from one
      // film to the other would reuse the mounted PlayerPage — the remote
      // would appear to do nothing.
      expect(
        playerPageKey(Uri.parse('/player/movie-a')),
        isNot(equals(playerPageKey(Uri.parse('/player/movie-b')))),
      );
    });

    test('the same location produces an equal key', () {
      expect(
        playerPageKey(Uri.parse('/player/movie-a')),
        equals(playerPageKey(Uri.parse('/player/movie-a'))),
      );
    });

    test('two episodes of one series produce different keys', () {
      expect(
        playerPageKey(Uri.parse('/player/episode/e1?series=s1')),
        isNot(equals(playerPageKey(Uri.parse('/player/episode/e2?series=s1')))),
      );
    });

    test('the same episode in a different series produces a different key', () {
      // The series context drives prev/next and auto-advance, so it has
      // to force a remount too.
      expect(
        playerPageKey(Uri.parse('/player/episode/e1?series=s1')),
        isNot(equals(playerPageKey(Uri.parse('/player/episode/e1?series=s2')))),
      );
    });

    test('switching to shuffle mode produces a different key', () {
      expect(
        playerPageKey(Uri.parse('/player/episode/e1?series=s1')),
        isNot(
          equals(
            playerPageKey(
              Uri.parse('/player/episode/e1?series=s1&mode=shuffle'),
            ),
          ),
        ),
      );
    });

    test('returns a ValueKey<String>', () {
      expect(playerPageKey(Uri.parse('/player/m1')), isA<ValueKey<String>>());
    });
  });
}
