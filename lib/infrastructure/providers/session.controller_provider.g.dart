// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'session.controller_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Central controller for [SessionState]. Single point of contact between
/// the UI and the application layer.

@ProviderFor(SessionController)
final sessionControllerProvider = SessionControllerProvider._();

/// Central controller for [SessionState]. Single point of contact between
/// the UI and the application layer.
final class SessionControllerProvider
    extends $NotifierProvider<SessionController, SessionState> {
  /// Central controller for [SessionState]. Single point of contact between
  /// the UI and the application layer.
  SessionControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'sessionControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$sessionControllerHash();

  @$internal
  @override
  SessionController create() => SessionController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SessionState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SessionState>(value),
    );
  }
}

String _$sessionControllerHash() => r'28d1d39b62418604ecdf7f745715bf9a95f7b1b0';

/// Central controller for [SessionState]. Single point of contact between
/// the UI and the application layer.

abstract class _$SessionController extends $Notifier<SessionState> {
  SessionState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<SessionState, SessionState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<SessionState, SessionState>,
              SessionState,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}

/// Bootstrap provider: triggers [SessionController.restoreSession] at
/// app startup. The UI waits on this before building the router.

@ProviderFor(bootstrap)
final bootstrapProvider = BootstrapProvider._();

/// Bootstrap provider: triggers [SessionController.restoreSession] at
/// app startup. The UI waits on this before building the router.

final class BootstrapProvider
    extends $FunctionalProvider<AsyncValue<void>, void, FutureOr<void>>
    with $FutureModifier<void>, $FutureProvider<void> {
  /// Bootstrap provider: triggers [SessionController.restoreSession] at
  /// app startup. The UI waits on this before building the router.
  BootstrapProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'bootstrapProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$bootstrapHash();

  @$internal
  @override
  $FutureProviderElement<void> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<void> create(Ref ref) {
    return bootstrap(ref);
  }
}

String _$bootstrapHash() => r'21189af28a72e26ccc2240f4ae11e863a854a300';
