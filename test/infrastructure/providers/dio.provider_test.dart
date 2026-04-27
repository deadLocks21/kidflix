import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kidflix/infrastructure/http/auth.interceptor.dart';
import 'package:kidflix/infrastructure/providers/dio.provider.dart';

void main() {
  group('dioProvider', () {
    test('returns a Dio instance with the configured timeouts', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final dio = container.read(dioProvider);

      expect(dio, isA<Dio>());
      expect(dio.options.connectTimeout, const Duration(seconds: 10));
      expect(dio.options.receiveTimeout, const Duration(seconds: 30));
      expect(dio.options.contentType, 'application/json');
      expect(dio.options.responseType, ResponseType.json);
    });

    test(
      'baseUrl is empty when API_BASE_URL is not provided at compile time',
      () {
        // `flutter test` never receives `--dart-define=API_BASE_URL`, so the
        // provider always sees an empty string here. This guards against an
        // accidental hardcoded baseUrl.
        final container = ProviderContainer();
        addTearDown(container.dispose);

        expect(container.read(dioProvider).options.baseUrl, isEmpty);
      },
    );

    test('registers exactly one AuthInterceptor', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final dio = container.read(dioProvider);

      expect(dio.interceptors.whereType<AuthInterceptor>(), hasLength(1));
    });
  });
}
