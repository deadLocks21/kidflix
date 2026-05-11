import 'package:flutter_test/flutter_test.dart';
import 'package:kidflix/infrastructure/avatars/in_memory.avatars.repository.dart';

void main() {
  group('InMemoryAvatarsRepository', () {
    test('list() returns a stable non-empty whitelist', () async {
      final repo = InMemoryAvatarsRepository();
      final result = await repo.list();
      expect(result, isNotEmpty);
      // Every entry has a well-formed id and a /static/avatars/ URL.
      for (final option in result) {
        expect(option.id, matches(RegExp(r'^[a-z0-9-]+$')));
        expect(option.url, startsWith('/static/avatars/'));
        expect(option.url, endsWith('.png'));
      }
    });

    test('list() is idempotent (same content across calls)', () async {
      final repo = InMemoryAvatarsRepository();
      final first = await repo.list();
      final second = await repo.list();
      expect(second, equals(first));
    });
  });
}
