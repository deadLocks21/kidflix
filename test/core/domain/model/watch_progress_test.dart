import 'package:flutter_test/flutter_test.dart';
import 'package:kidflix/core/domain/model/watch_progress.dart';

void main() {
  group('WatchProgress', () {
    test('equality by (profileId, movieId) only', () {
      final a = WatchProgress(
        profileId: 'p1',
        movieId: 'abc',
        positionSeconds: 100,
        completed: false,
        updatedAt: DateTime(2026, 4, 24, 10),
      );
      final b = WatchProgress(
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
      final a = WatchProgress(
        profileId: 'p1',
        movieId: 'abc',
        positionSeconds: 100,
        completed: false,
        updatedAt: DateTime(2026, 4, 24, 10),
      );
      final b = WatchProgress(
        profileId: 'p2',
        movieId: 'abc',
        positionSeconds: 100,
        completed: false,
        updatedAt: DateTime(2026, 4, 24, 10),
      );
      expect(a, isNot(equals(b)));
    });

    test('different movieId breaks equality', () {
      final a = WatchProgress(
        profileId: 'p1',
        movieId: 'abc',
        positionSeconds: 0,
        completed: false,
        updatedAt: DateTime(2026, 4, 24, 10),
      );
      final b = WatchProgress(
        profileId: 'p1',
        movieId: 'xyz',
        positionSeconds: 0,
        completed: false,
        updatedAt: DateTime(2026, 4, 24, 10),
      );
      expect(a, isNot(equals(b)));
    });
  });
}
