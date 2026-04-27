import 'package:flutter_test/flutter_test.dart';
import 'package:kidflix/core/domain/exceptions/unknown_profile.exception.dart';

void main() {
  group('UnknownProfileException', () {
    test('preserves the profile id passed to the constructor', () {
      const exception = UnknownProfileException('ar');

      expect(exception.profileId, 'ar');
    });

    test('toString includes the id between quotes', () {
      const exception = UnknownProfileException('papa');

      expect(exception.toString(), 'UnknownProfileException: "papa"');
    });
  });
}
