// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'auth.repository_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Auth repository provider.
///
/// Selects between two implementations based on the compile-time constant
/// `String.fromEnvironment('API_BASE_URL')`:
///
/// - **empty (default)** → [InMemoryAuthRepository] — used by tests, by
///   `flutter run` without flag, and by anyone running offline.
/// - **non-empty** → [DioAuthRepository] consuming [dioProvider] — used to
///   talk to the real backend, e.g.
///   `flutter run --dart-define=API_BASE_URL=http://localhost:8080`.
///
/// Switching modes requires a full rebuild — `String.fromEnvironment` is
/// evaluated at compile time, not at runtime.

@ProviderFor(authRepository)
final authRepositoryProvider = AuthRepositoryProvider._();

/// Auth repository provider.
///
/// Selects between two implementations based on the compile-time constant
/// `String.fromEnvironment('API_BASE_URL')`:
///
/// - **empty (default)** → [InMemoryAuthRepository] — used by tests, by
///   `flutter run` without flag, and by anyone running offline.
/// - **non-empty** → [DioAuthRepository] consuming [dioProvider] — used to
///   talk to the real backend, e.g.
///   `flutter run --dart-define=API_BASE_URL=http://localhost:8080`.
///
/// Switching modes requires a full rebuild — `String.fromEnvironment` is
/// evaluated at compile time, not at runtime.

final class AuthRepositoryProvider
    extends $FunctionalProvider<AuthRepository, AuthRepository, AuthRepository>
    with $Provider<AuthRepository> {
  /// Auth repository provider.
  ///
  /// Selects between two implementations based on the compile-time constant
  /// `String.fromEnvironment('API_BASE_URL')`:
  ///
  /// - **empty (default)** → [InMemoryAuthRepository] — used by tests, by
  ///   `flutter run` without flag, and by anyone running offline.
  /// - **non-empty** → [DioAuthRepository] consuming [dioProvider] — used to
  ///   talk to the real backend, e.g.
  ///   `flutter run --dart-define=API_BASE_URL=http://localhost:8080`.
  ///
  /// Switching modes requires a full rebuild — `String.fromEnvironment` is
  /// evaluated at compile time, not at runtime.
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

String _$authRepositoryHash() => r'cf6a67225de92fab7f12eeff3bf730eaffbbf787';
