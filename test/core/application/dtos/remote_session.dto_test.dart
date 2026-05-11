import 'package:flutter_test/flutter_test.dart';
import 'package:kidflix/core/application/dtos/remote_session.dto.dart';
import 'package:kidflix/core/domain/model/device.dart';
import 'package:kidflix/core/domain/model/profile.dart';

Map<String, dynamic> _profileJson({
  required String id,
  required String name,
  required String ageCategory,
  String? pinHash,
  String? avatarId,
  required bool isMain,
}) => {
  'id': id,
  'name': name,
  'age_category': ageCategory,
  'pin_hash': pinHash,
  'avatar_id': avatarId,
  'is_main': isMain,
};

void main() {
  group('RemoteSessionDto.fromJson', () {
    test('parses a complete verify-otp response (3 profiles)', () {
      final dto = RemoteSessionDto.fromJson({
        'jwt': 'eyJabc',
        'device': {'id': '9b2-uuid', 'name': 'iPhone de Papa'},
        'profiles': [
          _profileJson(
            id: 'papa',
            name: 'Papa',
            ageCategory: 'adulte',
            pinHash: r'$2b$12$X',
            isMain: true,
          ),
          _profileJson(
            id: 'ar',
            name: 'Ar',
            ageCategory: 'enfant',
            isMain: false,
          ),
          _profileJson(
            id: 'ro',
            name: 'Ro',
            ageCategory: 'ado',
            pinHash: r'$2b$12$Y',
            isMain: false,
          ),
        ],
      });

      expect(dto.jwt, 'eyJabc');
      expect(dto.device.id, '9b2-uuid');
      expect(dto.device.name, 'iPhone de Papa');
      expect(dto.profiles, hasLength(3));
      expect(dto.profiles[0].id, 'papa');
      expect(dto.profiles[1].ageCategory, AgeCategory.enfant);
      expect(dto.profiles[2].pinHash, r'$2b$12$Y');
    });

    test('parses null device.name', () {
      final dto = RemoteSessionDto.fromJson({
        'jwt': 'jwt',
        'device': {'id': 'abc', 'name': null},
        'profiles': <Map<String, dynamic>>[],
      });

      expect(dto.device.id, 'abc');
      expect(dto.device.name, isNull);
    });

    test('parses an empty profiles list without exception', () {
      final dto = RemoteSessionDto.fromJson({
        'jwt': 'jwt',
        'device': {'id': 'abc', 'name': 'Phone'},
        'profiles': <Map<String, dynamic>>[],
      });

      expect(dto.profiles, isEmpty);
      expect(dto.toDomain().profiles, isEmpty);
    });
  });

  group('RemoteSessionDto.toDomain', () {
    test(
      'produces a Session with matching jwt, Device, and Profiles list (in order)',
      () {
        final dto = RemoteSessionDto.fromJson({
          'jwt': 'eyJabc',
          'device': {'id': '9b2-uuid', 'name': 'iPhone de Papa'},
          'profiles': [
            _profileJson(
              id: 'papa',
              name: 'Papa',
              ageCategory: 'adulte',
              pinHash: r'$2b$12$X',
              isMain: true,
            ),
            _profileJson(
              id: 'ar',
              name: 'Ar',
              ageCategory: 'enfant',
              isMain: false,
            ),
          ],
        });

        final session = dto.toDomain();

        expect(session.jwt, 'eyJabc');
        expect(session.device, const Device(id: '9b2-uuid', name: 'iPhone de Papa'));
        expect(session.profiles, hasLength(2));
        expect(session.profiles[0].id, 'papa');
        expect(session.profiles[1].id, 'ar');
      },
    );
  });
}
