import 'package:flutter_test/flutter_test.dart';
import 'package:kidflix/core/domain/model/media.dart';
import 'package:kidflix/core/domain/model/profile.dart';

Movie _movie({
  String id = 'm1',
  String title = 'Title',
  List<String> genres = const [],
  String? sagaId,
  String? sagaLabel,
}) {
  return Movie(
    id: id,
    title: title,
    duration: const Duration(minutes: 90),
    synopsis: '',
    ageCategory: AgeCategory.enfant,
    genres: genres,
    director: const [],
    cast: const [],
    addedAt: DateTime(2026, 1, 1),
    sagaId: sagaId,
    sagaLabel: sagaLabel,
  );
}

Series _series({
  String id = 's1',
  String title = 'Pingu',
  int seasonsCount = 0,
  int episodesCount = 0,
  List<Season> seasons = const [],
  List<String> genres = const [],
}) {
  return Series(
    id: id,
    title: title,
    synopsis: '',
    ageCategory: AgeCategory.enfant,
    genres: genres,
    director: const [],
    cast: const [],
    addedAt: DateTime(2026, 1, 1),
    seasonsCount: seasonsCount,
    episodesCount: episodesCount,
    seasons: seasons,
  );
}

Episode _episode({
  String id = 'ep1',
  String seriesId = 's1',
  int seasonNumber = 1,
  int episodeNumber = 1,
}) {
  return Episode(
    id: id,
    seriesId: seriesId,
    seasonNumber: seasonNumber,
    episodeNumber: episodeNumber,
    title: 'Episode',
    duration: const Duration(minutes: 5),
    ageCategory: AgeCategory.enfant,
    addedAt: DateTime(2026, 1, 1),
  );
}

void main() {
  group('Movie', () {
    test('equality uses id', () {
      final a = _movie(id: 'x', title: 'A');
      final b = _movie(id: 'x', title: 'B');
      final c = _movie(id: 'y', title: 'A');
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });

    test('hasSaga is false when sagaId is null', () {
      expect(_movie().hasSaga, isFalse);
    });

    test('hasSaga is true when sagaId is non-empty', () {
      expect(_movie(sagaId: 'asterix', sagaLabel: 'Astérix').hasSaga, isTrue);
    });

    test('hasSaga is false when sagaId is empty string', () {
      expect(_movie(sagaId: '').hasSaga, isFalse);
    });

    test('primaryGenre is the first genre', () {
      final m = _movie(genres: const ['Familial', 'Comédie', 'Aventure']);
      expect(m.primaryGenre, 'Familial');
    });

    test('primaryGenre is null when genres is empty', () {
      expect(_movie().primaryGenre, isNull);
    });

    test('is a CatalogItem', () {
      final Object m = _movie();
      expect(m is CatalogItem, isTrue);
    });

    test('is a PlayableMedia', () {
      final Object m = _movie();
      expect(m is PlayableMedia, isTrue);
    });
  });

  group('Series', () {
    test('equality uses id', () {
      final a = _series(id: 'x', title: 'A');
      final b = _series(id: 'x', title: 'B');
      final c = _series(id: 'y', title: 'A');
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });

    test('seasons defaults to empty list', () {
      expect(_series().seasons, isEmpty);
    });

    test('seasonsCount and episodesCount may differ from local seasons.length',
        () {
      final s = _series(seasonsCount: 6, episodesCount: 105);
      expect(s.seasonsCount, 6);
      expect(s.episodesCount, 105);
      expect(s.seasons.length, 0);
    });

    test('is a CatalogItem', () {
      final Object s = _series();
      expect(s is CatalogItem, isTrue);
    });

    test('is NOT a PlayableMedia', () {
      final Object s = _series();
      expect(s is PlayableMedia, isFalse);
    });

    test('primaryGenre is the first genre', () {
      final s = _series(genres: const ['Animation', 'Familial']);
      expect(s.primaryGenre, 'Animation');
    });
  });

  group('Episode', () {
    test('equality uses id', () {
      final a = _episode(id: 'x');
      final b = _episode(id: 'x', episodeNumber: 99);
      final c = _episode(id: 'y');
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });

    test('is a PlayableMedia', () {
      final Object e = _episode();
      expect(e is PlayableMedia, isTrue);
    });

    test('is NOT a CatalogItem', () {
      final Object e = _episode();
      expect(e is CatalogItem, isFalse);
    });

    test('toString contains the season and episode reference', () {
      final e = _episode(seasonNumber: 2, episodeNumber: 5);
      expect(e.toString(), contains('S2E5'));
    });
  });

  group('Season', () {
    test('isSpecials when seasonNumber is 0', () {
      const s = Season(seasonNumber: 0, episodes: []);
      expect(s.isSpecials, isTrue);
    });

    test('isSpecials false when seasonNumber > 0', () {
      const s = Season(seasonNumber: 1, episodes: []);
      expect(s.isSpecials, isFalse);
    });
  });

  group('CatalogItem sealed switch', () {
    test('exhaustive switch covers Movie and Series', () {
      String label(CatalogItem item) {
        return switch (item) {
          Movie() => 'movie',
          Series() => 'series',
        };
      }

      expect(label(_movie()), 'movie');
      expect(label(_series()), 'series');
    });
  });

  group('PlayableMedia sealed switch', () {
    test('exhaustive switch covers Movie and Episode', () {
      String label(PlayableMedia media) {
        return switch (media) {
          Movie() => 'movie',
          Episode() => 'episode',
        };
      }

      expect(label(_movie()), 'movie');
      expect(label(_episode()), 'episode');
    });
  });

  group('CastMember', () {
    test('role and photoUrl are optional', () {
      const c = CastMember(name: 'Guillaume Canet');
      expect(c.role, isNull);
      expect(c.photoUrl, isNull);
    });
  });
}
