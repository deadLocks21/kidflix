import 'package:flutter_test/flutter_test.dart';
import 'package:kidflix/infrastructure/kids_lock/noop.kids_lock.service.dart';

void main() {
  group('NoopKidsLockService', () {
    const service = NoopKidsLockService();

    test('startLock returns false', () async {
      expect(await service.startLock(), isFalse);
    });

    test('stopLock returns true (semantic: nothing to stop)', () async {
      expect(await service.stopLock(), isTrue);
    });

    test('isLocked returns false', () async {
      expect(await service.isLocked(), isFalse);
    });

    test('repeated calls are safe and consistent', () async {
      for (var i = 0; i < 5; i++) {
        expect(await service.startLock(), isFalse);
        expect(await service.stopLock(), isTrue);
        expect(await service.isLocked(), isFalse);
      }
    });
  });
}
