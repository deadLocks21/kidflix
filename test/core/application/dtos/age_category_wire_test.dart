import 'package:flutter_test/flutter_test.dart';
import 'package:kidflix/core/application/dtos/age_category_wire.dart';
import 'package:kidflix/core/domain/model/profile.dart';

void main() {
  group('ageCategoryToWire', () {
    test('maps each variant to its snake_case wire string', () {
      expect(ageCategoryToWire(AgeCategory.bebe), 'bebe');
      expect(ageCategoryToWire(AgeCategory.enfant), 'enfant');
      expect(ageCategoryToWire(AgeCategory.ado), 'ado');
      expect(ageCategoryToWire(AgeCategory.jeuneAdulte), 'jeune_adulte');
      expect(ageCategoryToWire(AgeCategory.adulte), 'adulte');
    });
  });

  group('ageCategoryFromWire', () {
    test('parses each wire string to its enum variant', () {
      expect(ageCategoryFromWire('bebe'), AgeCategory.bebe);
      expect(ageCategoryFromWire('enfant'), AgeCategory.enfant);
      expect(ageCategoryFromWire('ado'), AgeCategory.ado);
      expect(ageCategoryFromWire('jeune_adulte'), AgeCategory.jeuneAdulte);
      expect(ageCategoryFromWire('adulte'), AgeCategory.adulte);
    });

    test('throws FormatException on unknown value', () {
      expect(
        () => ageCategoryFromWire('teen'),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('Unknown age_category'),
          ).having(
            (e) => e.message,
            'message',
            contains('teen'),
          ),
        ),
      );
    });

    test('throws FormatException on empty string', () {
      expect(() => ageCategoryFromWire(''), throwsA(isA<FormatException>()));
    });
  });

  test('round-trip is lossless for every variant', () {
    for (final v in AgeCategory.values) {
      expect(
        ageCategoryFromWire(ageCategoryToWire(v)),
        v,
        reason: 'round-trip failed for $v',
      );
    }
  });
}
