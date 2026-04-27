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
/// **No auth interceptors are registered here.** The `/auth/*` endpoints are
/// public per `API.md`, so an `Authorization: Bearer <jwt>` /
/// `X-Device-Id: <uuid>` interceptor would be dead code at this stage. They
/// must be added when the first protected capability (catalog,
/// profile-management, …) is ported to HTTP.

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
/// **No auth interceptors are registered here.** The `/auth/*` endpoints are
/// public per `API.md`, so an `Authorization: Bearer <jwt>` /
/// `X-Device-Id: <uuid>` interceptor would be dead code at this stage. They
/// must be added when the first protected capability (catalog,
/// profile-management, …) is ported to HTTP.

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
  /// **No auth interceptors are registered here.** The `/auth/*` endpoints are
  /// public per `API.md`, so an `Authorization: Bearer <jwt>` /
  /// `X-Device-Id: <uuid>` interceptor would be dead code at this stage. They
  /// must be added when the first protected capability (catalog,
  /// profile-management, …) is ported to HTTP.
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

String _$dioHash() => r'b031b8620aa6dacb14ed89ff57fa7cec80f18e81';
