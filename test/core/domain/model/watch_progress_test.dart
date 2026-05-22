import 'package:flutter_test/flutter_test.dart';
import 'package:kidflix/core/domain/model/watch_progress.dart';

void main() {
  group('MovieProgress', () {
    test('equality by (profileId, movieId) only', () {
      final a = MovieProgress(
        profileId: 'p1',
        movieId: 'abc',
        positionSeconds: 100,
        completed: false,
        updatedAt: DateTime(2026, 4, 24, 10),
      );
      final b = MovieProgress(
        profileId: 'p1',
        movieId: 'abc',
        positionSeconds: 500,
        completed: true,
        updatedAt: DateTime(2026, 4, 24, 11),
      );
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('different profileId breaks equality', () {
      final a = MovieProgress(
        profileId: 'p1',
        movieId: 'abc',
        positionSeconds: 100,
        completed: false,
        updatedAt: DateTime(2026, 4, 24, 10),
      );
      final b = MovieProgress(
        profileId: 'p2',
        movieId: 'abc',
        positionSeconds: 100,
        completed: false,
        updatedAt: DateTime(2026, 4, 24, 10),
      );
      expect(a, isNot(equals(b)));
    });

    test('different movieId breaks equality', () {
      final a = MovieProgress(
        profileId: 'p1',
        movieId: 'abc',
        positionSeconds: 0,
        completed: false,
        updatedAt: DateTime(2026, 4, 24, 10),
      );
      final b = MovieProgress(
        profileId: 'p1',
        movieId: 'xyz',
        positionSeconds: 0,
        completed: false,
        updatedAt: DateTime(2026, 4, 24, 10),
      );
      expect(a, isNot(equals(b)));
    });
  });

  group('EpisodeProgress', () {
    test('equality by (profileId, episodeId) only', () {
      final a = EpisodeProgress(
        profileId: 'p1',
        episodeId: 'ep1',
        positionSeconds: 100,
        completed: false,
        updatedAt: DateTime(2026, 5, 4, 10),
      );
      final b = EpisodeProgress(
        profileId: 'p1',
        episodeId: 'ep1',
        positionSeconds: 500,
        completed: true,
        updatedAt: DateTime(2026, 5, 4, 11),
      );
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('different episodeId breaks equality', () {
      final a = EpisodeProgress(
        profileId: 'p1',
        episodeId: 'ep1',
        positionSeconds: 0,
        completed: false,
        updatedAt: DateTime(2026, 5, 4, 10),
      );
      final b = EpisodeProgress(
        profileId: 'p1',
        episodeId: 'ep2',
        positionSeconds: 0,
        completed: false,
        updatedAt: DateTime(2026, 5, 4, 10),
      );
      expect(a, isNot(equals(b)));
    });
  });

  group('WatchProgress sealed cross-kind equality', () {
    test(
      'MovieProgress and EpisodeProgress with identical id strings are not equal',
      () {
        final m = MovieProgress(
          profileId: 'p1',
          movieId: 'x',
          positionSeconds: 0,
          completed: false,
          updatedAt: DateTime(2026, 5, 4),
        );
        final e = EpisodeProgress(
          profileId: 'p1',
          episodeId: 'x',
          positionSeconds: 0,
          completed: false,
          updatedAt: DateTime(2026, 5, 4),
        );
        expect(m == e, isFalse);
        expect(e == m, isFalse);
      },
    );

    test('exhaustive switch covers MovieProgress and EpisodeProgress', () {
      String label(WatchProgress p) {
        return switch (p) {
          MovieProgress() => 'movie',
          EpisodeProgress() => 'episode',
        };
      }

      final m = MovieProgress(
        profileId: 'p1',
        movieId: 'x',
        positionSeconds: 0,
        completed: false,
        updatedAt: DateTime(2026, 5, 4),
      );
      final e = EpisodeProgress(
        profileId: 'p1',
        episodeId: 'x',
        positionSeconds: 0,
        completed: false,
        updatedAt: DateTime(2026, 5, 4),
      );
      expect(label(m), 'movie');
      expect(label(e), 'episode');
    });
  });
}
