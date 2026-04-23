// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'auth.repository_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Auth repository provider.
///
/// Currently always returns [InMemoryAuthRepository]. Will gain an HTTP
/// variant when the backend is available.

@ProviderFor(authRepository)
final authRepositoryProvider = AuthRepositoryProvider._();

/// Auth repository provider.
///
/// Currently always returns [InMemoryAuthRepository]. Will gain an HTTP
/// variant when the backend is available.

final class AuthRepositoryProvider
    extends $FunctionalProvider<AuthRepository, AuthRepository, AuthRepository>
    with $Provider<AuthRepository> {
  /// Auth repository provider.
  ///
  /// Currently always returns [InMemoryAuthRepository]. Will gain an HTTP
  /// variant when the backend is available.
  AuthRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'authRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$authRepositoryHash();

  @$internal
  @override
  $ProviderElement<AuthRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AuthRepository create(Ref ref) {
    return authRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AuthRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AuthRepository>(value),
    );
  }
}

String _$authRepositoryHash() => r'9af987b973c8d30aa8458f6b8cdeca15aa7b6e01';
