import 'package:flutter_test/flutter_test.dart';
import 'package:kidflix/core/domain/model/movie.dart';
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
  });

  group('CastMember', () {
    test('role and photoUrl are optional', () {
      const c = CastMember(name: 'Guillaume Canet');
      expect(c.role, isNull);
      expect(c.photoUrl, isNull);
    });
  });
}
