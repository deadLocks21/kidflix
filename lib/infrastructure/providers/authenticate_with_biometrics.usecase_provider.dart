import 'package:kidflix/core/application/usecases/authenticate_with_biometrics.usecase.dart';
import 'package:kidflix/infrastructure/providers/biometric_auth.service_provider.dart';
import 'package:kidflix/infrastructure/providers/biometric_preferences.provider.dart';
import 'package:kidflix/infrastructure/providers/logger.service_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'authenticate_with_biometrics.usecase_provider.g.dart';

@Riverpod(keepAlive: true)
AuthenticateWithBiometricsUseCase authenticateWithBiometricsUseCase(Ref ref) {
  return AuthenticateWithBiometricsUseCase(
    ref.watch(biometricPreferencesProvider),
    ref.watch(biometricAuthServiceProvider),
    ref.watch(loggerProvider),
  );
}
