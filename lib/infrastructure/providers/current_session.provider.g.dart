// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'current_session.provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Derived view over [SessionState]: the [Session] currently established (if
/// any), or `null` for `Anonymous` / `OtpRequested`.
///
/// Consumed by the `AuthInterceptor` registered on `dioProvider` to read
/// `jwt` and `device.id` at every request, and reusable by any future
/// component that needs the active session without knowing the state machine
/// (logging, debug overlay, refresh interceptor…).
///
/// The exhaustive `switch` over the sealed [SessionState] guarantees a
/// compile-time error if a new variant is added without updating this
/// mapping.

@ProviderFor(currentSession)
final currentSessionProvider = CurrentSessionProvider._();

/// Derived view over [SessionState]: the [Session] currently established (if
/// any), or `null` for `Anonymous` / `OtpRequested`.
///
/// Consumed by the `AuthInterceptor` registered on `dioProvider` to read
/// `jwt` and `device.id` at every request, and reusable by any future
/// component that needs the active session without knowing the state machine
/// (logging, debug overlay, refresh interceptor…).
///
/// The exhaustive `switch` over the sealed [SessionState] guarantees a
/// compile-time error if a new variant is added without updating this
/// mapping.

final class CurrentSessionProvider
    extends $FunctionalProvider<Session?, Session?, Session?>
    with $Provider<Session?> {
  /// Derived view over [SessionState]: the [Session] currently established (if
  /// any), or `null` for `Anonymous` / `OtpRequested`.
  ///
  /// Consumed by the `AuthInterceptor` registered on `dioProvider` to read
  /// `jwt` and `device.id` at every request, and reusable by any future
  /// component that needs the active session without knowing the state machine
  /// (logging, debug overlay, refresh interceptor…).
  ///
  /// The exhaustive `switch` over the sealed [SessionState] guarantees a
  /// compile-time error if a new variant is added without updating this
  /// mapping.
  CurrentSessionProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'currentSessionProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$currentSessionHash();

  @$internal
  @override
  $ProviderElement<Session?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  Session? create(Ref ref) {
    return currentSession(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Session? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Session?>(value),
    );
  }
}

String _$currentSessionHash() => r'82c784b886a337be4f25cfbcd29d2a0eef8be8c3';
