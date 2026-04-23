import 'package:flutter_test/flutter_test.dart';
import 'package:kidflix/core/domain/exceptions/invalid_phone_number.exception.dart';
import 'package:kidflix/core/domain/model/phone_number.dart';

void main() {
  group('PhoneNumber', () {
    test('accepts a well-formatted mobile number', () {
      expect(PhoneNumber.parse('0612345678').e164, '+33612345678');
    });

    test('strips whitespace, dots and hyphens before validation', () {
      expect(PhoneNumber.parse('06 12.34-56 78').e164, '+33612345678');
    });

    test('rejects numbers not starting with 06 or 07', () {
      expect(
        () => PhoneNumber.parse('0112345678'),
        throwsA(isA<InvalidPhoneNumberException>()),
      );
    });

    test('rejects numbers with wrong length', () {
      expect(
        () => PhoneNumber.parse('061234567'),
        throwsA(isA<InvalidPhoneNumberException>()),
      );
    });
  });
}
