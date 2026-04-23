// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'auth.service_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(authService)
final authServiceProvider = AuthServiceProvider._();

final class AuthServiceProvider
    extends
        $FunctionalProvider<
          AuthApplicationService,
          AuthApplicationService,
          AuthApplicationService
        >
    with $Provider<AuthApplicationService> {
  AuthServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'authServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$authServiceHash();

  @$internal
  @override
  $ProviderElement<AuthApplicationService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  AuthApplicationService create(Ref ref) {
    return authService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AuthApplicationService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AuthApplicationService>(value),
    );
  }
}

String _$authServiceHash() => r'932a0371c102101e50c46f36c6f34a84152b7442';
