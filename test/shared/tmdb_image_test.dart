import 'package:flutter_test/flutter_test.dart';
import 'package:kidflix/shared/tmdb_image.dart';

void main() {
  group('tmdbResize', () {
    test('rewrites the size segment of a TMDB URL', () {
      expect(
        tmdbResize('https://image.tmdb.org/t/p/original/abc.jpg', 'w342'),
        'https://image.tmdb.org/t/p/w342/abc.jpg',
      );
    });

    test('rewrites between two named sizes', () {
      expect(
        tmdbResize('https://image.tmdb.org/t/p/w780/abc.jpg', 'w185'),
        'https://image.tmdb.org/t/p/w185/abc.jpg',
      );
    });

    test('returns the url unchanged when it is not a TMDB image url', () {
      expect(
        tmdbResize('https://example.com/posters/abc.jpg', 'w342'),
        'https://example.com/posters/abc.jpg',
      );
    });

    test('returns the url unchanged when the size segment is missing', () {
      expect(
        tmdbResize('https://image.tmdb.org/abc.jpg', 'w342'),
        'https://image.tmdb.org/abc.jpg',
      );
    });
  });
}
