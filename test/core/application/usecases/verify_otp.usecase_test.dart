import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kidflix/core/application/services/logger_application.service.dart';
import 'package:kidflix/core/application/usecases/verify_otp.usecase.dart';
import 'package:kidflix/core/domain/exceptions/device_already_registered.exception.dart';
import 'package:kidflix/core/domain/exceptions/invalid_otp.exception.dart';
import 'package:kidflix/core/domain/exceptions/otp_expired.exception.dart';
import 'package:kidflix/core/domain/model/device.dart';
import 'package:kidflix/core/domain/model/log_level.dart';
import 'package:kidflix/core/domain/model/otp_code.dart';
import 'package:kidflix/core/domain/model/phone_number.dart';
import 'package:kidflix/core/domain/model/profile.dart';
import 'package:kidflix/core/domain/model/session.dart';
import 'package:kidflix/core/domain/services/auth.repository.dart';
import 'package:kidflix/infrastructure/logger/in_memory.logger.service.dart';

/// [AuthRepository] whose `verifyOtp` either returns [session] or throws
/// [error]. Only `verifyOtp` is exercised here.
class _FakeAuthRepository implements AuthRepository {
  final Session? session;
  final Object? error;

  _FakeAuthRepository({this.session, this.error});

  @override
  Future<DateTime> requestOtp(PhoneNumber phoneNumber) async =>
      throw UnimplementedError();

  @override
  Future<Session> verifyOtp(
    PhoneNumber phoneNumber,
    OtpCode code,
    Device device,
  ) async {
    final err = error;
    if (err != null) throw err;
    return session!;
  }

  @override
  Future<List<Profile>> fetchProfiles() async => throw UnimplementedError();
}

void main() {
  final phone = PhoneNumber.parse('0612345678');
  const device = Device(id: 'abc');

  ({VerifyOtpUseCase useCase, InMemoryLoggerService logs}) build({
    Session? session,
    Object? error,
  }) {
    final logs = InMemoryLoggerService();
    return (
      useCase: VerifyOtpUseCase(
        _FakeAuthRepository(session: session, error: error),
        LoggerApplicationService(logs),
      ),
      logs: logs,
    );
  }

  Future<VerifyOtpResult> run(VerifyOtpUseCase useCase) =>
      useCase.execute(phone: phone, rawCode: '123456', device: device);

  group('VerifyOtpUseCase', () {
    test('returns success carrying the repository session', () async {
      const session = Session(
        jwt: 'eyJabc',
        device: device,
        profiles: [
          Profile(
            id: 'papa',
            name: 'Papa',
            ageCategory: AgeCategory.adulte,
            isMain: true,
          ),
        ],
      );
      final (:useCase, :logs) = build(session: session);

      final result = await run(useCase);

      expect(result, isA<VerifyOtpSuccess>());
      expect((result as VerifyOtpSuccess).session.jwt, 'eyJabc');
    });

    test('maps InvalidOtpException to VerifyOtpInvalidCode', () async {
      final (:useCase, :logs) = build(error: const InvalidOtpException());

      expect(await run(useCase), isA<VerifyOtpInvalidCode>());
    });

    test('maps OtpExpiredException to VerifyOtpExpired', () async {
      final (:useCase, :logs) = build(error: const OtpExpiredException());

      expect(await run(useCase), isA<VerifyOtpExpired>());
    });

    test(
      'maps DeviceAlreadyRegisteredException to '
      'VerifyOtpDeviceAlreadyRegistered',
      () async {
        final (:useCase, :logs) = build(
          error: const DeviceAlreadyRegisteredException(),
        );

        expect(await run(useCase), isA<VerifyOtpDeviceAlreadyRegistered>());
      },
    );

    test('maps a network DioException to VerifyOtpFailure', () async {
      final (:useCase, :logs) = build(
        error: DioException.connectionError(
          requestOptions: RequestOptions(path: '/auth/verify-otp'),
          reason: 'network down',
        ),
      );

      expect(await run(useCase), isA<VerifyOtpFailure>());
    });

    test('maps an unmapped 409 DioException to VerifyOtpFailure', () async {
      final options = RequestOptions(path: '/auth/verify-otp');
      final (:useCase, :logs) = build(
        error: DioException.badResponse(
          statusCode: 409,
          requestOptions: options,
          response: Response<dynamic>(requestOptions: options, statusCode: 409),
        ),
      );

      expect(await run(useCase), isA<VerifyOtpFailure>());
    });

    test('maps an arbitrary non-Dio error to VerifyOtpFailure', () async {
      final (:useCase, :logs) = build(error: StateError('secure storage down'));

      expect(await run(useCase), isA<VerifyOtpFailure>());
    });

    test('never lets an exception escape to the caller', () async {
      final (:useCase, :logs) = build(error: StateError('boom'));

      // Le point du fix : l'appelant reçoit toujours un résultat, jamais
      // une exception — sans ça l'écran OTP reste figé sur son spinner.
      await expectLater(run(useCase), completes);
    });

    test('logs failures at warn with the error and its stack', () async {
      final (:useCase, :logs) = build(
        error: const DeviceAlreadyRegisteredException(),
      );

      await run(useCase);

      final record = logs.records.single;
      expect(record.level, LogLevel.warn);
      expect(record.message, 'auth.verify_otp.failed');
      expect(record.error, isA<DeviceAlreadyRegisteredException>());
      expect(record.stack, isNotNull);
    });

    test('does not log the OTP code nor the phone number', () async {
      final (:useCase, :logs) = build(error: StateError('boom'));

      await run(useCase);

      for (final record in logs.records) {
        final dump = '${record.message} ${record.attributes} ${record.error}';
        expect(dump, isNot(contains('123456')));
        expect(dump, isNot(contains('612345678')));
      }
    });

    test('rejects a syntactically invalid code without calling the '
        'repository', () async {
      final logs = InMemoryLoggerService();
      final useCase = VerifyOtpUseCase(
        _FakeAuthRepository(error: StateError('should not be reached')),
        LoggerApplicationService(logs),
      );

      final result = await useCase.execute(
        phone: phone,
        rawCode: '12',
        device: device,
      );

      expect(result, isA<VerifyOtpInvalidCode>());
    });
  });
}
