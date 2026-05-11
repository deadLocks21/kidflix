import 'package:flutter_test/flutter_test.dart';
import 'package:kidflix/core/application/dtos/remote_avatars.dto.dart';

void main() {
  group('RemoteAvatarsDto.fromJson', () {
    test('parses the full catalogue envelope', () {
      final dto = RemoteAvatarsDto.fromJson({
        'avatars': [
          {'id': 'cat-01', 'url': '/static/avatars/cat-01.svg'},
          {'id': 'panda-01', 'url': '/static/avatars/panda-01.svg'},
        ],
      });

      expect(dto.avatars, hasLength(2));
      expect(dto.avatars[0].id, 'cat-01');
      expect(dto.avatars[0].url, '/static/avatars/cat-01.svg');
      expect(dto.avatars[1].id, 'panda-01');
    });

    test('accepts an empty avatars list without exception', () {
      final dto = RemoteAvatarsDto.fromJson({'avatars': <Map<String, dynamic>>[]});
      expect(dto.avatars, isEmpty);
      expect(dto.toDomain(), isEmpty);
    });

    test('toDomain preserves order and field values', () {
      final dto = RemoteAvatarsDto.fromJson({
        'avatars': [
          {'id': 'a', 'url': '/static/avatars/a.svg'},
          {'id': 'b', 'url': '/static/avatars/b.svg'},
          {'id': 'c', 'url': '/static/avatars/c.svg'},
        ],
      });

      final domain = dto.toDomain();
      expect(domain.map((o) => o.id), ['a', 'b', 'c']);
      expect(domain.map((o) => o.url), [
        '/static/avatars/a.svg',
        '/static/avatars/b.svg',
        '/static/avatars/c.svg',
      ]);
    });
  });
}
