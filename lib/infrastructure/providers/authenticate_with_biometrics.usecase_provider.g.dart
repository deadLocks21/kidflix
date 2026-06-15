// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'authenticate_with_biometrics.usecase_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(authenticateWithBiometricsUseCase)
final authenticateWithBiometricsUseCaseProvider =
    AuthenticateWithBiometricsUseCaseProvider._();

final class AuthenticateWithBiometricsUseCaseProvider
    extends
        $FunctionalProvider<
          AuthenticateWithBiometricsUseCase,
          AuthenticateWithBiometricsUseCase,
          AuthenticateWithBiometricsUseCase
        >
    with $Provider<AuthenticateWithBiometricsUseCase> {
  AuthenticateWithBiometricsUseCaseProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'authenticateWithBiometricsUseCaseProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() =>
      _$authenticateWithBiometricsUseCaseHash();

  @$internal
  @override
  $ProviderElement<AuthenticateWithBiometricsUseCase> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  AuthenticateWithBiometricsUseCase create(Ref ref) {
    return authenticateWithBiometricsUseCase(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AuthenticateWithBiometricsUseCase value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AuthenticateWithBiometricsUseCase>(
        value,
      ),
    );
  }
}

String _$authenticateWithBiometricsUseCaseHash() =>
    r'1160a3feeb99d9c5aff96f1ba03aea9a721cf196';
