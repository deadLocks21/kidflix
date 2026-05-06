import 'package:flutter_test/flutter_test.dart';
import 'package:kidflix/core/application/dtos/remote_watch_progress.dto.dart';
import 'package:kidflix/core/domain/model/watch_progress.dart';

Map<String, dynamic> _moviePayload() => {
  'kind': 'movie',
  'profile_id': 'p1',
  'media_id': 'm1',
  'position_seconds': 1845,
  'completed': false,
  'updated_at': '2026-04-22T10:30:00Z',
};

Map<String, dynamic> _episodePayload() => {
  'kind': 'episode',
  'profile_id': 'p1',
  'media_id': 'ep-uuid-2',
  'position_seconds': 240,
  'completed': false,
  'updated_at': '2026-05-04T18:30:00Z',
};

void main() {
  group('watchProgressFromJson', () {
    test('parses a movie entry into MovieProgress', () {
      final progress = watchProgressFromJson(_moviePayload());

      expect(progress, isA<MovieProgress>());
      final movie = progress as MovieProgress;
      expect(movie.profileId, 'p1');
      expect(movie.movieId, 'm1');
      expect(movie.positionSeconds, 1845);
      expect(movie.completed, isFalse);
      expect(movie.updatedAt, DateTime.utc(2026, 4, 22, 10, 30));
    });

    test('parses an episode entry into EpisodeProgress', () {
      final progress = watchProgressFromJson(_episodePayload());

      expect(progress, isA<EpisodeProgress>());
      final ep = progress as EpisodeProgress;
      expect(ep.profileId, 'p1');
      expect(ep.episodeId, 'ep-uuid-2');
      expect(ep.positionSeconds, 240);
      expect(ep.completed, isFalse);
      expect(ep.updatedAt, DateTime.utc(2026, 5, 4, 18, 30));
    });

    test('throws on unknown kind', () {
      final payload = _moviePayload()..['kind'] = 'podcast';

      expect(
        () => watchProgressFromJson(payload),
        throwsA(isA<FormatException>()),
      );
    });

    test('throws on missing kind', () {
      final payload = _moviePayload()..remove('kind');

      expect(
        () => watchProgressFromJson(payload),
        throwsA(isA<FormatException>()),
      );
    });

    test('throws when a required field is missing', () {
      final payload = _moviePayload()..remove('position_seconds');

      expect(
        () => watchProgressFromJson(payload),
        throwsA(isA<TypeError>()),
      );
    });

    test('parses completed: true', () {
      final payload = _moviePayload()..['completed'] = true;

      final progress = watchProgressFromJson(payload);

      expect(progress.completed, isTrue);
    });
  });

  group('watchProgressToWireBody', () {
    test('produces the PUT body for a MovieProgress', () {
      final progress = MovieProgress(
        profileId: 'p1',
        movieId: 'm1',
        positionSeconds: 1900,
        completed: false,
        updatedAt: DateTime.utc(2026, 4, 22, 10, 30, 10),
      );

      final body = watchProgressToWireBody(progress);

      expect(body, {
        'position_seconds': 1900,
        'completed': false,
      });
    });

    test('produces the PUT body for an EpisodeProgress', () {
      final progress = EpisodeProgress(
        profileId: 'p1',
        episodeId: 'ep1',
        positionSeconds: 240,
        completed: false,
        updatedAt: DateTime.utc(2026, 5, 4, 18, 30),
      );

      final body = watchProgressToWireBody(progress);

      expect(body['position_seconds'], 240);
      expect(body['completed'], isFalse);
    });

    test('omits profile_id and media_id (path-only)', () {
      final progress = MovieProgress(
        profileId: 'p1',
        movieId: 'm1',
        positionSeconds: 100,
        completed: false,
        updatedAt: DateTime.utc(2026, 4, 22),
      );

      final body = watchProgressToWireBody(progress);

      expect(body.containsKey('profile_id'), isFalse);
      expect(body.containsKey('media_id'), isFalse);
      expect(body.containsKey('movie_id'), isFalse);
      expect(body.containsKey('episode_id'), isFalse);
      expect(body.containsKey('kind'), isFalse);
    });

    test('serializes completed: true', () {
      final progress = MovieProgress(
        profileId: 'p1',
        movieId: 'm1',
        positionSeconds: 5400,
        completed: true,
        updatedAt: DateTime.utc(2026, 4, 22, 11, 0, 0),
      );

      final body = watchProgressToWireBody(progress);

      expect(body['completed'], isTrue);
    });
  });
}
