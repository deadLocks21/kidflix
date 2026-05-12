// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'dio.provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Centralized Dio HTTP client shared by every `dio.<thing>.repository.dart`.
///
/// The `baseUrl` is sourced from [apiBaseUrlProvider], which lets the user
/// pick a backend at runtime via the ⚙ dialog on the phone-entry page.
/// Persistence is handled by `SharedPreferences`; the compile-time constant
/// `String.fromEnvironment('API_BASE_URL')` is used as a fallback when
/// nothing has ever been stored. An empty URL keeps the app in in-memory
/// mode (the repository providers select their `InMemory*` implementations).
///
/// Example launches that bake an initial URL into the build:
///
/// ```sh
/// flutter run --dart-define=API_BASE_URL=http://localhost:8080  # iOS Simulator
/// flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080   # Android emulator
/// ```
///
/// Changing the URL at runtime invalidates this provider via the
/// `ref.watch` below, so a fresh `Dio` instance is created with the new
/// `baseUrl` (losing the connection pool — acceptable for an infrequent
/// configuration change).
///
/// An [AuthInterceptor] is wired in to add `Authorization: Bearer <jwt>`,
/// `X-Device-Id: <uuid>` and `X-Profile-Id: <profile_id>` headers on every
/// protected request, sourcing the current session from
/// [currentSessionProvider] and the active profile id from
/// [currentProfileIdProvider]. The interceptor itself skips the public
/// `/auth/*` endpoints (no header at all) and exempts `GET /profiles` from
/// `X-Profile-Id` injection (bootstrap route).
///
/// Both callbacks are read via `ref.read` (not `ref.watch`) so login/logout
/// transitions AND profile-selection transitions do NOT rebuild this `Dio`.
/// The interceptor reads the latest values lazily at every request.

@ProviderFor(dio)
final dioProvider = DioProvider._();

/// Centralized Dio HTTP client shared by every `dio.<thing>.repository.dart`.
///
/// The `baseUrl` is sourced from [apiBaseUrlProvider], which lets the user
/// pick a backend at runtime via the ⚙ dialog on the phone-entry page.
/// Persistence is handled by `SharedPreferences`; the compile-time constant
/// `String.fromEnvironment('API_BASE_URL')` is used as a fallback when
/// nothing has ever been stored. An empty URL keeps the app in in-memory
/// mode (the repository providers select their `InMemory*` implementations).
///
/// Example launches that bake an initial URL into the build:
///
/// ```sh
/// flutter run --dart-define=API_BASE_URL=http://localhost:8080  # iOS Simulator
/// flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080   # Android emulator
/// ```
///
/// Changing the URL at runtime invalidates this provider via the
/// `ref.watch` below, so a fresh `Dio` instance is created with the new
/// `baseUrl` (losing the connection pool — acceptable for an infrequent
/// configuration change).
///
/// An [AuthInterceptor] is wired in to add `Authorization: Bearer <jwt>`,
/// `X-Device-Id: <uuid>` and `X-Profile-Id: <profile_id>` headers on every
/// protected request, sourcing the current session from
/// [currentSessionProvider] and the active profile id from
/// [currentProfileIdProvider]. The interceptor itself skips the public
/// `/auth/*` endpoints (no header at all) and exempts `GET /profiles` from
/// `X-Profile-Id` injection (bootstrap route).
///
/// Both callbacks are read via `ref.read` (not `ref.watch`) so login/logout
/// transitions AND profile-selection transitions do NOT rebuild this `Dio`.
/// The interceptor reads the latest values lazily at every request.

final class DioProvider extends $FunctionalProvider<Dio, Dio, Dio>
    with $Provider<Dio> {
  /// Centralized Dio HTTP client shared by every `dio.<thing>.repository.dart`.
  ///
  /// The `baseUrl` is sourced from [apiBaseUrlProvider], which lets the user
  /// pick a backend at runtime via the ⚙ dialog on the phone-entry page.
  /// Persistence is handled by `SharedPreferences`; the compile-time constant
  /// `String.fromEnvironment('API_BASE_URL')` is used as a fallback when
  /// nothing has ever been stored. An empty URL keeps the app in in-memory
  /// mode (the repository providers select their `InMemory*` implementations).
  ///
  /// Example launches that bake an initial URL into the build:
  ///
  /// ```sh
  /// flutter run --dart-define=API_BASE_URL=http://localhost:8080  # iOS Simulator
  /// flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080   # Android emulator
  /// ```
  ///
  /// Changing the URL at runtime invalidates this provider via the
  /// `ref.watch` below, so a fresh `Dio` instance is created with the new
  /// `baseUrl` (losing the connection pool — acceptable for an infrequent
  /// configuration change).
  ///
  /// An [AuthInterceptor] is wired in to add `Authorization: Bearer <jwt>`,
  /// `X-Device-Id: <uuid>` and `X-Profile-Id: <profile_id>` headers on every
  /// protected request, sourcing the current session from
  /// [currentSessionProvider] and the active profile id from
  /// [currentProfileIdProvider]. The interceptor itself skips the public
  /// `/auth/*` endpoints (no header at all) and exempts `GET /profiles` from
  /// `X-Profile-Id` injection (bootstrap route).
  ///
  /// Both callbacks are read via `ref.read` (not `ref.watch`) so login/logout
  /// transitions AND profile-selection transitions do NOT rebuild this `Dio`.
  /// The interceptor reads the latest values lazily at every request.
  DioProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'dioProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$dioHash();

  @$internal
  @override
  $ProviderElement<Dio> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  Dio create(Ref ref) {
    return dio(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Dio value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Dio>(value),
    );
  }
}

String _$dioHash() => r'b8ddc9b24566b2174359cef7d576fd5455256304';
