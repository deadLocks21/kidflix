import 'package:flutter_test/flutter_test.dart';
import 'package:kidflix/core/application/dtos/remote_movie.dto.dart';
import 'package:kidflix/core/domain/model/media.dart';
import 'package:kidflix/core/domain/model/profile.dart';

Map<String, dynamic> _asterixJson() => {
  'id': 'asterix-empire-du-milieu',
  'title': 'Astérix & Obélix : L\'Empire du Milieu',
  'original_title': 'Astérix & Obélix : L\'Empire du Milieu',
  'year': 2023,
  'duration_seconds': 6720,
  'synopsis': 'Nous sommes en 50 avant J.C. …',
  'tagline': 'Il y a très très longtemps…',
  'poster_url': 'https://image.tmdb.org/t/p/original/poster.jpg',
  'backdrop_url': 'https://image.tmdb.org/t/p/original/backdrop.jpg',
  'logo_url': 'https://image.tmdb.org/t/p/original/logo.png',
  'trailer_url':
      'plugin://plugin.video.youtube/play/?video_id=fet2dxgJGNk',
  'age_category': 'enfant',
  'genres': ['Familial', 'Comédie', 'Aventure', 'Fantastique'],
  'saga_id': 'asterix',
  'saga_label': 'Astérix',
  'director': ['Guillaume Canet'],
  'cast': [
    {'name': 'Guillaume Canet', 'role': 'Astérix', 'photo_url': null},
    {'name': 'Gilles Lellouche', 'role': 'Obélix', 'photo_url': null},
    {'name': 'Vincent Cassel', 'role': 'Jules César', 'photo_url': null},
    {'name': 'Jonathan Cohen', 'role': 'Graindemaïs', 'photo_url': null},
    {'name': 'Julie Chen', 'role': 'Princesse Fu Yi', 'photo_url': null},
    {'name': 'Marion Cotillard', 'role': 'Cléopâtre / Bibine', 'photo_url': null},
    {'name': 'Pierre Richard', 'role': 'Panoramix', 'photo_url': null},
  ],
  'added_at': '2026-04-20T00:00:00Z',
};

void main() {
  group('RemoteMovieDto.fromJson', () {
    test('parses every field of a complete payload', () {
      final dto = RemoteMovieDto.fromJson(_asterixJson());

      expect(dto.id, 'asterix-empire-du-milieu');
      expect(dto.title, 'Astérix & Obélix : L\'Empire du Milieu');
      expect(dto.originalTitle, 'Astérix & Obélix : L\'Empire du Milieu');
      expect(dto.year, 2023);
      expect(dto.durationSeconds, 6720);
      expect(dto.synopsis, 'Nous sommes en 50 avant J.C. …');
      expect(dto.tagline, 'Il y a très très longtemps…');
      expect(dto.posterUrl, 'https://image.tmdb.org/t/p/original/poster.jpg');
      expect(
        dto.backdropUrl,
        'https://image.tmdb.org/t/p/original/backdrop.jpg',
      );
      expect(dto.logoUrl, 'https://image.tmdb.org/t/p/original/logo.png');
      expect(
        dto.trailerUrl,
        'plugin://plugin.video.youtube/play/?video_id=fet2dxgJGNk',
      );
      expect(dto.ageCategory, AgeCategory.enfant);
      expect(dto.genres, ['Familial', 'Comédie', 'Aventure', 'Fantastique']);
      expect(dto.sagaId, 'asterix');
      expect(dto.sagaLabel, 'Astérix');
      expect(dto.director, ['Guillaume Canet']);
      expect(dto.cast, hasLength(7));
      expect(dto.addedAt, DateTime.parse('2026-04-20T00:00:00Z'));
    });

    test('toDomain projects to Movie with proper Duration and CastMembers', () {
      final movie = RemoteMovieDto.fromJson(_asterixJson()).toDomain();

      expect(movie, isA<Movie>());
      expect(movie.id, 'asterix-empire-du-milieu');
      expect(movie.duration, const Duration(seconds: 6720));
      expect(movie.duration, const Duration(minutes: 112));
      expect(movie.ageCategory, AgeCategory.enfant);
      expect(movie.addedAt, DateTime.parse('2026-04-20T00:00:00Z'));
      expect(movie.cast, hasLength(7));
      expect(movie.cast.first, isA<CastMember>());
      expect(movie.cast.first.name, 'Guillaume Canet');
      expect(movie.cast.first.role, 'Astérix');
    });

    test('parses a payload with all nullable fields absent', () {
      final json = {
        'id': 'minimal',
        'title': 'Minimal Movie',
        'original_title': null,
        'year': null,
        'duration_seconds': 5400,
        'synopsis': '',
        'tagline': null,
        'poster_url': null,
        'backdrop_url': null,
        'age_category': 'bebe',
        'genres': <String>[],
        'saga_id': null,
        'saga_label': null,
        'director': <String>[],
        'cast': <Map<String, dynamic>>[],
        'added_at': '2026-04-22T10:00:00Z',
      };

      final dto = RemoteMovieDto.fromJson(json);
      final movie = dto.toDomain();

      expect(movie.originalTitle, isNull);
      expect(movie.year, isNull);
      expect(movie.tagline, isNull);
      expect(movie.posterUrl, isNull);
      expect(movie.backdropUrl, isNull);
      expect(movie.logoUrl, isNull);
      expect(movie.trailerUrl, isNull);
      expect(movie.sagaId, isNull);
      expect(movie.sagaLabel, isNull);
      expect(movie.cast, isEmpty);
      expect(movie.genres, isEmpty);
      expect(movie.director, isEmpty);
      expect(movie.duration, const Duration(seconds: 5400));
    });

    test('toDomain projects trailer_url through to the Movie', () {
      final movie = RemoteMovieDto.fromJson(_asterixJson()).toDomain();

      expect(
        movie.trailerUrl,
        'plugin://plugin.video.youtube/play/?video_id=fet2dxgJGNk',
      );
    });

    test('toDomain projects logo_url through to the Movie', () {
      final movie = RemoteMovieDto.fromJson(_asterixJson()).toDomain();

      expect(movie.logoUrl, 'https://image.tmdb.org/t/p/original/logo.png');
    });

    test('throws FormatException on unknown age_category wire value', () {
      final json = _asterixJson()..['age_category'] = 'teen';

      expect(
        () => RemoteMovieDto.fromJson(json),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('RemoteCastMemberDto.fromJson', () {
    test('parses a fully populated cast entry', () {
      final dto = RemoteCastMemberDto.fromJson({
        'name': 'Guillaume Canet',
        'role': 'Astérix',
        'photo_url': 'https://example.com/portrait.jpg',
      });

      expect(dto.name, 'Guillaume Canet');
      expect(dto.role, 'Astérix');
      expect(dto.photoUrl, 'https://example.com/portrait.jpg');

      final member = dto.toDomain();
      expect(member, isA<CastMember>());
      expect(member.name, 'Guillaume Canet');
      expect(member.role, 'Astérix');
      expect(member.photoUrl, 'https://example.com/portrait.jpg');
    });

    test('parses a cast entry with null role and photo_url', () {
      final dto = RemoteCastMemberDto.fromJson({
        'name': 'Hayao Miyazaki',
        'role': null,
        'photo_url': null,
      });
      final member = dto.toDomain();

      expect(member.name, 'Hayao Miyazaki');
      expect(member.role, isNull);
      expect(member.photoUrl, isNull);
    });
  });

  group('RemoteMovieDto wire compatibility with kind discriminator', () {
    test('tolerates a top-level "kind" field in the payload', () {
      final payload = _asterixJson()..['kind'] = 'movie';

      final dto = RemoteMovieDto.fromJson(payload);

      expect(dto.id, 'asterix-empire-du-milieu');
      expect(dto.title, contains('Astérix'));
    });

    test('parses without a "kind" field (legacy fixtures)', () {
      final payload = Map<String, dynamic>.from(_asterixJson());
      expect(payload.containsKey('kind'), isFalse);

      final dto = RemoteMovieDto.fromJson(payload);

      expect(dto.id, 'asterix-empire-du-milieu');
    });
  });
}
