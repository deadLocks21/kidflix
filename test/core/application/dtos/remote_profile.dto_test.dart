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
        'avatar_url': null,
        'is_main': false,
      });

      expect(dto.id, 'ar');
      expect(dto.name, 'Ar');
      expect(dto.ageCategory, AgeCategory.enfant);
      expect(dto.pinHash, isNull);
      expect(dto.avatarUrl, isNull);
      expect(dto.isMain, isFalse);
    });

    test('parses main profile with PIN hash and avatar URL', () {
      final dto = RemoteProfileDto.fromJson({
        'id': 'papa',
        'name': 'Papa',
        'age_category': 'adulte',
        'pin_hash': r'$2b$12$abc',
        'avatar_url': 'https://example.com/papa.png',
        'is_main': true,
      });

      expect(dto.pinHash, r'$2b$12$abc');
      expect(dto.avatarUrl, 'https://example.com/papa.png');
      expect(dto.isMain, isTrue);
      expect(dto.ageCategory, AgeCategory.adulte);
    });

    test('maps "jeune_adulte" wire string to AgeCategory.jeuneAdulte', () {
      final dto = RemoteProfileDto.fromJson({
        'id': 'x',
        'name': 'X',
        'age_category': 'jeune_adulte',
        'pin_hash': null,
        'avatar_url': null,
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
          'avatar_url': null,
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
      for (final wire in [
        'bebe',
        'enfant',
        'ado',
        'jeune_adulte',
        'adulte',
      ]) {
        final json = {
          'id': 'p-$wire',
          'name': 'Profile $wire',
          'age_category': wire,
          'pin_hash': null,
          'avatar_url': null,
          'is_main': false,
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
      expect(profile.avatarUrl, isNull);
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
