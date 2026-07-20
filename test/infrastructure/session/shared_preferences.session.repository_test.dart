import 'package:flutter_test/flutter_test.dart';
import 'package:kidflix/core/domain/model/device.dart';
import 'package:kidflix/core/domain/model/phone_number.dart';
import 'package:kidflix/core/domain/model/profile.dart';
import 'package:kidflix/core/domain/model/session.dart';
import 'package:kidflix/infrastructure/session/shared_preferences.session.repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('SharedPreferencesSessionRepository — phone number', () {
    test('returns null when nothing was persisted', () async {
      final repo = SharedPreferencesSessionRepository();
      expect(await repo.readPhoneNumber(), isNull);
    });

    test('round-trips a phone number', () async {
      final repo = SharedPreferencesSessionRepository();
      await repo.writePhoneNumber(PhoneNumber.parse('0612345678'));

      expect(
        await repo.readPhoneNumber(),
        PhoneNumber.fromE164('+33612345678'),
      );
    });

    test('overwrites a previously persisted number', () async {
      final repo = SharedPreferencesSessionRepository();
      await repo.writePhoneNumber(PhoneNumber.parse('0612345678'));
      await repo.writePhoneNumber(PhoneNumber.parse('0798765432'));

      expect(
        await repo.readPhoneNumber(),
        PhoneNumber.fromE164('+33798765432'),
      );
    });

    test('reads back null rather than throwing on a corrupt value', () async {
      SharedPreferences.setMockInitialValues({'kidflix.phone_number': 'nope'});
      final repo = SharedPreferencesSessionRepository();

      expect(await repo.readPhoneNumber(), isNull);
    });

    test('survives a session write/read cycle', () async {
      final repo = SharedPreferencesSessionRepository();
      await repo.write(_session);
      await repo.writePhoneNumber(PhoneNumber.parse('0612345678'));

      expect(await repo.read(), isNotNull);
      expect(await repo.readPhoneNumber(), isNotNull);
    });

    test('clearSessionPreserveDevice drops the phone with the JWT', () async {
      final repo = SharedPreferencesSessionRepository();
      await repo.write(_session);
      await repo.writePhoneNumber(PhoneNumber.parse('0612345678'));

      await repo.clearSessionPreserveDevice();

      expect(await repo.read(), isNull);
      expect(await repo.readPhoneNumber(), isNull);
      // Device id is the one thing that must outlive a logout.
      expect((await repo.readOrCreateDevice()).id, 'uuid-1');
    });

    test('clear drops the phone too', () async {
      final repo = SharedPreferencesSessionRepository();
      await repo.write(_session);
      await repo.writePhoneNumber(PhoneNumber.parse('0612345678'));

      await repo.clear();

      expect(await repo.readPhoneNumber(), isNull);
    });
  });
}

final Session _session = Session(
  jwt: 'eyJabc',
  device: const Device(id: 'uuid-1', name: null),
  profiles: const [
    Profile(
      id: 'papa',
      name: 'Papa',
      ageCategory: AgeCategory.adulte,
      pinHash: r'$2b$12$abc',
      isMain: true,
    ),
  ],
);
