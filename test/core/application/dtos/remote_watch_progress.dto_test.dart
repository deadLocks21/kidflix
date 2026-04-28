import 'package:flutter_test/flutter_test.dart';
import 'package:kidflix/core/application/dtos/remote_watch_progress.dto.dart';
import 'package:kidflix/core/domain/model/watch_progress.dart';

Map<String, dynamic> _samplePayload() => {
  'profile_id': 'p1',
  'movie_id': 'm1',
  'position_seconds': 1845,
  'completed': false,
  'updated_at': '2026-04-22T10:30:00Z',
};

void main() {
  group('RemoteWatchProgressDto.fromJson', () {
    test('parses every field of a complete payload', () {
      final dto = RemoteWatchProgressDto.fromJson(_samplePayload());

      expect(dto.profileId, 'p1');
      expect(dto.movieId, 'm1');
      expect(dto.positionSeconds, 1845);
      expect(dto.completed, isFalse);
      expect(dto.updatedAt, DateTime.utc(2026, 4, 22, 10, 30));
    });

    test('throws when a required field is missing', () {
      final payload = _samplePayload()..remove('position_seconds');

      expect(
        () => RemoteWatchProgressDto.fromJson(payload),
        throwsA(isA<TypeError>()),
      );
    });

    test('parses completed: true', () {
      final payload = _samplePayload()..['completed'] = true;

      final dto = RemoteWatchProgressDto.fromJson(payload);

      expect(dto.completed, isTrue);
    });
  });

  group('RemoteWatchProgressDto.toDomain', () {
    test('projects to a faithful WatchProgress', () {
      final progress = RemoteWatchProgressDto.fromJson(_samplePayload())
          .toDomain();

      expect(progress, isA<WatchProgress>());
      expect(progress.profileId, 'p1');
      expect(progress.movieId, 'm1');
      expect(progress.positionSeconds, 1845);
      expect(progress.completed, isFalse);
      expect(progress.updatedAt, DateTime.utc(2026, 4, 22, 10, 30));
    });
  });

  group('RemoteWatchProgressDto.toWireBody', () {
    test('produces the PUT body with only position_seconds and completed', () {
      final dto = RemoteWatchProgressDto(
        profileId: 'p1',
        movieId: 'm1',
        positionSeconds: 1900,
        completed: false,
        updatedAt: DateTime.utc(2026, 4, 22, 10, 30, 10),
      );

      final body = dto.toWireBody();

      expect(body, {
        'position_seconds': 1900,
        'completed': false,
      });
    });

    test('omits profile_id and movie_id (path-only)', () {
      final dto = RemoteWatchProgressDto(
        profileId: 'p1',
        movieId: 'm1',
        positionSeconds: 100,
        completed: false,
        updatedAt: DateTime.utc(2026, 4, 22),
      );

      final body = dto.toWireBody();

      expect(body.containsKey('profile_id'), isFalse);
      expect(body.containsKey('movie_id'), isFalse);
    });

    test('omits updated_at (server stamps its own clock)', () {
      final dto = RemoteWatchProgressDto(
        profileId: 'p1',
        movieId: 'm1',
        positionSeconds: 100,
        completed: false,
        updatedAt: DateTime.utc(2026, 4, 22, 10, 30, 10, 123, 456),
      );

      final body = dto.toWireBody();

      expect(body.containsKey('updated_at'), isFalse);
    });

    test('serializes completed: true', () {
      final dto = RemoteWatchProgressDto(
        profileId: 'p1',
        movieId: 'm1',
        positionSeconds: 5400,
        completed: true,
        updatedAt: DateTime.utc(2026, 4, 22, 11, 0, 0),
      );

      final body = dto.toWireBody();

      expect(body['completed'], isTrue);
    });
  });
}
