import 'package:flutter_test/flutter_test.dart';
import 'package:kidflix/infrastructure/biometric/noop.biometric_auth.service.dart';

void main() {
  group('NoopBiometricAuthService', () {
    const service = NoopBiometricAuthService();

    test('isAvailable returns false', () async {
      expect(await service.isAvailable(), isFalse);
    });

    test('authenticate returns false', () async {
      expect(await service.authenticate(reason: 'unlock'), isFalse);
    });

    test('repeated calls are safe and consistent', () async {
      for (var i = 0; i < 5; i++) {
        expect(await service.isAvailable(), isFalse);
        expect(await service.authenticate(reason: 'unlock'), isFalse);
      }
    });
  });
}
