import 'package:flutter/foundation.dart';
import 'package:kidflix/core/domain/services/biometric_auth.service.dart';
import 'package:kidflix/infrastructure/biometric/local_auth.biometric_auth.service.dart';
import 'package:kidflix/infrastructure/biometric/noop.biometric_auth.service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'biometric_auth.service_provider.g.dart';

/// Returns the [BiometricAuthService] implementation matching the
/// current platform: `local_auth` on iOS / Android, a noop everywhere
/// else. The platform is constant for the app lifetime, so the
/// selection is evaluated once at provider creation (same approach as
/// `kidsLockServiceProvider`).
@Riverpod(keepAlive: true)
BiometricAuthService biometricAuthService(Ref ref) {
  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
    case TargetPlatform.iOS:
      return LocalAuthBiometricService();
    case TargetPlatform.fuchsia:
    case TargetPlatform.linux:
    case TargetPlatform.macOS:
    case TargetPlatform.windows:
      return const NoopBiometricAuthService();
  }
}
