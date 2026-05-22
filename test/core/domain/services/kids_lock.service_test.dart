import 'package:flutter_test/flutter_test.dart';
import 'package:kidflix/core/domain/services/kids_lock.service.dart';

void main() {
  group('KidsLockService contract', () {
    test(
      'any subclass can be instantiated and exposes the three methods',
      () async {
        final KidsLockService service = _FakeKidsLockService();
        expect(await service.startLock(), isTrue);
        expect(await service.stopLock(), isTrue);
        expect(await service.isLocked(), isFalse);
      },
    );
  });
}

class _FakeKidsLockService implements KidsLockService {
  @override
  Future<bool> startLock() async => true;

  @override
  Future<bool> stopLock() async => true;

  @override
  Future<bool> isLocked() async => false;
}
