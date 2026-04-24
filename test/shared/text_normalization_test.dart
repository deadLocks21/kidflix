import 'package:flutter_test/flutter_test.dart';
import 'package:kidflix/shared/text_normalization.dart';

void main() {
  group('normalizeForSearch', () {
    test('lowercases', () {
      expect(normalizeForSearch('TOTORO'), 'totoro');
    });

    test('trims leading and trailing whitespace', () {
      expect(normalizeForSearch('  hello  '), 'hello');
    });

    test('folds French diacritics', () {
      expect(normalizeForSearch('Astérix'), 'asterix');
      expect(normalizeForSearch('école'), 'ecole');
      expect(normalizeForSearch('François'), 'francois');
      expect(normalizeForSearch('déjà vu'), 'deja vu');
    });

    test('folds uppercase diacritics via lowercase pass', () {
      expect(normalizeForSearch('ÉCOLE'), 'ecole');
      expect(normalizeForSearch('Ô'), 'o');
    });

    test('folds other common Latin diacritics', () {
      expect(normalizeForSearch('mañana'), 'manana');
      expect(normalizeForSearch('São'), 'sao');
      expect(normalizeForSearch('über'), 'uber');
    });

    test('passes digits, punctuation and unmapped chars through', () {
      expect(normalizeForSearch('Blade Runner 2049'), 'blade runner 2049');
      expect(normalizeForSearch("L'Empire"), "l'empire");
      expect(normalizeForSearch('Wall-E'), 'wall-e');
    });

    test('empty and whitespace-only input returns empty string', () {
      expect(normalizeForSearch(''), '');
      expect(normalizeForSearch('   '), '');
    });
  });
}
