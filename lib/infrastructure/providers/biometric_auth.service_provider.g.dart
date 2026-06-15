// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'biometric_auth.service_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Returns the [BiometricAuthService] implementation matching the
/// current platform: `local_auth` on iOS / Android, a noop everywhere
/// else. The platform is constant for the app lifetime, so the
/// selection is evaluated once at provider creation (same approach as
/// `kidsLockServiceProvider`).

@ProviderFor(biometricAuthService)
final biometricAuthServiceProvider = BiometricAuthServiceProvider._();

/// Returns the [BiometricAuthService] implementation matching the
/// current platform: `local_auth` on iOS / Android, a noop everywhere
/// else. The platform is constant for the app lifetime, so the
/// selection is evaluated once at provider creation (same approach as
/// `kidsLockServiceProvider`).

final class BiometricAuthServiceProvider
    extends
        $FunctionalProvider<
          BiometricAuthService,
          BiometricAuthService,
          BiometricAuthService
        >
    with $Provider<BiometricAuthService> {
  /// Returns the [BiometricAuthService] implementation matching the
  /// current platform: `local_auth` on iOS / Android, a noop everywhere
  /// else. The platform is constant for the app lifetime, so the
  /// selection is evaluated once at provider creation (same approach as
  /// `kidsLockServiceProvider`).
  BiometricAuthServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'biometricAuthServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$biometricAuthServiceHash();

  @$internal
  @override
  $ProviderElement<BiometricAuthService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  BiometricAuthService create(Ref ref) {
    return biometricAuthService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(BiometricAuthService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<BiometricAuthService>(value),
    );
  }
}

String _$biometricAuthServiceHash() =>
    r'ba532fccfe515363a0bbdcc7405b5a93597ea51e';
