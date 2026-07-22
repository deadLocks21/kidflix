import 'package:flutter_test/flutter_test.dart';
import 'package:kidflix/core/application/dtos/remote_profile.dto.dart';
import 'package:kidflix/core/domain/model/profile.dart';

void main() {
  group('RemoteProfileDto.fromJson', () {
    test('parses a complete payload (enfant, no PIN, no avatar)', () {
      final dto = RemoteProfileDto.fromJson({
        'id': 'ar',
        'name': 'Ar',
        'age_category': 'enfant',
        'pin_hash': null,
        'avatar_id': null,
        'is_main': false,
      });

      expect(dto.id, 'ar');
      expect(dto.name, 'Ar');
      expect(dto.ageCategory, AgeCategory.enfant);
      expect(dto.pinHash, isNull);
      expect(dto.avatarId, isNull);
      expect(dto.isMain, isFalse);
    });

    test('parses main profile with PIN hash and avatar id', () {
      final dto = RemoteProfileDto.fromJson({
        'id': 'papa',
        'name': 'Papa',
        'age_category': 'adulte',
        'pin_hash': r'$2b$12$abc',
        'avatar_id': 'cat-01',
        'is_main': true,
      });

      expect(dto.pinHash, r'$2b$12$abc');
      expect(dto.avatarId, 'cat-01');
      expect(dto.isMain, isTrue);
      expect(dto.ageCategory, AgeCategory.adulte);
    });

    test('defaults to owned when sharing fields are absent', () {
      // Compat descendante : un backend antérieur au partage ne renvoie que
      // des profils possédés. Les omettre doit donner "à moi, modifiable",
      // surtout pas l'inverse (qui griserait les actions à tort).
      final dto = RemoteProfileDto.fromJson({
        'id': 'ar',
        'name': 'Ar',
        'age_category': 'enfant',
        'pin_hash': null,
        'avatar_id': null,
        'is_main': false,
      });

      expect(dto.shared, isFalse);
      expect(dto.canManage, isTrue);
      expect(dto.toDomain().canDelete, isTrue);
    });

    test('parses a shared read-only profile', () {
      final dto = RemoteProfileDto.fromJson({
        'id': 'ar',
        'name': 'Ar',
        'age_category': 'enfant',
        'pin_hash': null,
        'avatar_id': null,
        'is_main': false,
        'shared': true,
        'can_manage': false,
      });

      expect(dto.shared, isTrue);
      expect(dto.canManage, isFalse);

      final profile = dto.toDomain();
      expect(profile.shared, isTrue);
      expect(profile.canManage, isFalse);
      expect(profile.canDelete, isFalse);
    });

    test('a shared profile stays undeletable even when manageable', () {
      // `can_manage` couvre l'édition, jamais la suppression : celle-ci
      // cascade sur les données du foyer propriétaire.
      final profile = RemoteProfileDto.fromJson({
        'id': 'ar',
        'name': 'Ar',
        'age_category': 'enfant',
        'pin_hash': null,
        'avatar_id': null,
        'is_main': false,
        'shared': true,
        'can_manage': true,
      }).toDomain();

      expect(profile.canManage, isTrue);
      expect(profile.canDelete, isFalse);
    });

    test('maps "jeune_adulte" wire string to AgeCategory.jeuneAdulte', () {
      final dto = RemoteProfileDto.fromJson({
        'id': 'x',
        'name': 'X',
        'age_category': 'jeune_adulte',
        'pin_hash': null,
        'avatar_id': null,
        'is_main': false,
      });

      expect(dto.ageCategory, AgeCategory.jeuneAdulte);
    });

    test('rejects unknown age_category with FormatException', () {
      expect(
        () => RemoteProfileDto.fromJson({
          'id': 'x',
          'name': 'X',
          'age_category': 'extraterrestre',
          'pin_hash': null,
          'avatar_id': null,
          'is_main': false,
        }),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('extraterrestre'),
          ),
        ),
      );
    });
  });

  group('RemoteProfileDto.toJson', () {
    test('round-trips losslessly for every age category', () {
      for (final wire in ['bebe', 'enfant', 'ado', 'jeune_adulte', 'adulte']) {
        final json = {
          'id': 'p-$wire',
          'name': 'Profile $wire',
          'age_category': wire,
          'pin_hash': null,
          'avatar_id': null,
          'is_main': false,
          'included_lower_age_categories': const <String>[],
          'shared': false,
          'can_manage': true,
        };

        expect(
          RemoteProfileDto.fromJson(json).toJson(),
          json,
          reason: 'round-trip failed for age_category=$wire',
        );
      }
    });

    test('emits "jeune_adulte" for AgeCategory.jeuneAdulte', () {
      final dto = const RemoteProfileDto(
        id: 'x',
        name: 'X',
        ageCategory: AgeCategory.jeuneAdulte,
        isMain: false,
      );

      expect(dto.toJson()['age_category'], 'jeune_adulte');
    });
  });

  group('RemoteProfileDto.toDomain', () {
    test('produces a Profile with matching field values', () {
      final dto = const RemoteProfileDto(
        id: 'papa',
        name: 'Papa',
        ageCategory: AgeCategory.adulte,
        pinHash: r'$2b$12$abc',
        isMain: true,
      );

      final profile = dto.toDomain();

      expect(profile.id, 'papa');
      expect(profile.name, 'Papa');
      expect(profile.ageCategory, AgeCategory.adulte);
      expect(profile.pinHash, r'$2b$12$abc');
      expect(profile.avatarId, isNull);
      expect(profile.isMain, isTrue);
      expect(profile.hasPin, isTrue);
    });

    test('produces a Profile with hasPin == false when pinHash is null', () {
      final dto = const RemoteProfileDto(
        id: 'ar',
        name: 'Ar',
        ageCategory: AgeCategory.enfant,
        isMain: false,
      );

      expect(dto.toDomain().hasPin, isFalse);
    });
  });
}
