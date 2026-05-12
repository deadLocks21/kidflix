// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'auth.repository_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Auth repository provider.
///
/// Selects between two implementations based on [apiBaseUrlProvider]:
///
/// - **empty** → [InMemoryAuthRepository] — used by tests and when no
///   backend has been configured.
/// - **non-empty** → [DioAuthRepository] consuming [dioProvider] — talks
///   to the real backend at the URL configured by the user via the ⚙
///   dialog on the phone-entry page (persisted in `shared_preferences`).
///
/// The URL changes at runtime invalidate this provider via the
/// `ref.watch` below, so the next call uses the freshly built repository.

@ProviderFor(authRepository)
final authRepositoryProvider = AuthRepositoryProvider._();

/// Auth repository provider.
///
/// Selects between two implementations based on [apiBaseUrlProvider]:
///
/// - **empty** → [InMemoryAuthRepository] — used by tests and when no
///   backend has been configured.
/// - **non-empty** → [DioAuthRepository] consuming [dioProvider] — talks
///   to the real backend at the URL configured by the user via the ⚙
///   dialog on the phone-entry page (persisted in `shared_preferences`).
///
/// The URL changes at runtime invalidate this provider via the
/// `ref.watch` below, so the next call uses the freshly built repository.

final class AuthRepositoryProvider
    extends $FunctionalProvider<AuthRepository, AuthRepository, AuthRepository>
    with $Provider<AuthRepository> {
  /// Auth repository provider.
  ///
  /// Selects between two implementations based on [apiBaseUrlProvider]:
  ///
  /// - **empty** → [InMemoryAuthRepository] — used by tests and when no
  ///   backend has been configured.
  /// - **non-empty** → [DioAuthRepository] consuming [dioProvider] — talks
  ///   to the real backend at the URL configured by the user via the ⚙
  ///   dialog on the phone-entry page (persisted in `shared_preferences`).
  ///
  /// The URL changes at runtime invalidate this provider via the
  /// `ref.watch` below, so the next call uses the freshly built repository.
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

String _$authRepositoryHash() => r'38075cb05ec61953b41a6d524b779d36d63d2f42';
