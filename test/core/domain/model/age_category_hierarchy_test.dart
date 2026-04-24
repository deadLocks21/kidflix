import 'package:flutter_test/flutter_test.dart';
import 'package:kidflix/core/domain/model/profile.dart';

void main() {
  group('AgeCategoryHierarchy.lowerOrEqual', () {
    test('bebe includes only itself', () {
      expect(AgeCategory.bebe.lowerOrEqual, [AgeCategory.bebe]);
    });

    test('enfant includes bebe and enfant', () {
      expect(AgeCategory.enfant.lowerOrEqual, [
        AgeCategory.bebe,
        AgeCategory.enfant,
      ]);
    });

    test('ado includes bebe, enfant, ado', () {
      expect(AgeCategory.ado.lowerOrEqual, [
        AgeCategory.bebe,
        AgeCategory.enfant,
        AgeCategory.ado,
      ]);
    });

    test('jeuneAdulte includes bebe, enfant, ado, jeuneAdulte', () {
      expect(AgeCategory.jeuneAdulte.lowerOrEqual, [
        AgeCategory.bebe,
        AgeCategory.enfant,
        AgeCategory.ado,
        AgeCategory.jeuneAdulte,
      ]);
    });

    test('adulte includes every category in order', () {
      expect(AgeCategory.adulte.lowerOrEqual, AgeCategory.values);
    });
  });
}
