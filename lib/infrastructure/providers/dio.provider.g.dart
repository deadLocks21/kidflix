// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'dio.provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Centralized Dio HTTP client shared by every `dio.<thing>.repository.dart`.
///
/// The `baseUrl` is resolved from the compile-time constant
/// `String.fromEnvironment('API_BASE_URL')` so the build defaults to an empty
/// URL (in-memory mode) and switches to HTTP when launched with
/// `--dart-define=API_BASE_URL=...`.
///
/// Example launches against a local backend:
///
/// ```sh
/// flutter run --dart-define=API_BASE_URL=http://localhost:8080  # iOS Simulator
/// flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080   # Android emulator
/// ```
///
/// An [AuthInterceptor] is wired in to add `Authorization: Bearer <jwt>` and
/// `X-Device-Id: <uuid>` headers on every protected request, sourcing the
/// current session from [currentSessionProvider]. The interceptor itself
/// skips the public `/auth/*` endpoints — they expect no auth headers per
/// `API.md` § Conventions.
///
/// The session is read via `ref.read` (not `ref.watch`) inside the
/// interceptor's callback so login/logout transitions do NOT rebuild this
/// `Dio` (which would lose the connection pool). The interceptor reads the
/// latest session lazily at every request.

@ProviderFor(dio)
final dioProvider = DioProvider._();

/// Centralized Dio HTTP client shared by every `dio.<thing>.repository.dart`.
///
/// The `baseUrl` is resolved from the compile-time constant
/// `String.fromEnvironment('API_BASE_URL')` so the build defaults to an empty
/// URL (in-memory mode) and switches to HTTP when launched with
/// `--dart-define=API_BASE_URL=...`.
///
/// Example launches against a local backend:
///
/// ```sh
/// flutter run --dart-define=API_BASE_URL=http://localhost:8080  # iOS Simulator
/// flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080   # Android emulator
/// ```
///
/// An [AuthInterceptor] is wired in to add `Authorization: Bearer <jwt>` and
/// `X-Device-Id: <uuid>` headers on every protected request, sourcing the
/// current session from [currentSessionProvider]. The interceptor itself
/// skips the public `/auth/*` endpoints — they expect no auth headers per
/// `API.md` § Conventions.
///
/// The session is read via `ref.read` (not `ref.watch`) inside the
/// interceptor's callback so login/logout transitions do NOT rebuild this
/// `Dio` (which would lose the connection pool). The interceptor reads the
/// latest session lazily at every request.

final class DioProvider extends $FunctionalProvider<Dio, Dio, Dio>
    with $Provider<Dio> {
  /// Centralized Dio HTTP client shared by every `dio.<thing>.repository.dart`.
  ///
  /// The `baseUrl` is resolved from the compile-time constant
  /// `String.fromEnvironment('API_BASE_URL')` so the build defaults to an empty
  /// URL (in-memory mode) and switches to HTTP when launched with
  /// `--dart-define=API_BASE_URL=...`.
  ///
  /// Example launches against a local backend:
  ///
  /// ```sh
  /// flutter run --dart-define=API_BASE_URL=http://localhost:8080  # iOS Simulator
  /// flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080   # Android emulator
  /// ```
  ///
  /// An [AuthInterceptor] is wired in to add `Authorization: Bearer <jwt>` and
  /// `X-Device-Id: <uuid>` headers on every protected request, sourcing the
  /// current session from [currentSessionProvider]. The interceptor itself
  /// skips the public `/auth/*` endpoints — they expect no auth headers per
  /// `API.md` § Conventions.
  ///
  /// The session is read via `ref.read` (not `ref.watch`) inside the
  /// interceptor's callback so login/logout transitions do NOT rebuild this
  /// `Dio` (which would lose the connection pool). The interceptor reads the
  /// latest session lazily at every request.
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

String _$dioHash() => r'6f85eb1344ebf179d0dac01dbf489bcac4033ed6';
