// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'refresh_profiles.usecase_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provides the `RefreshProfilesUseCase` wired against the active
/// [AuthRepository] (in-memory or HTTP, per `API_BASE_URL`).
///
/// The usecase only fetches the new profile list — it does not mutate
/// state. The `SessionController.refreshProfiles` orchestrator consumes
/// this provider, calls `execute()`, and then calls `replaceProfiles(...)`
/// on itself to persist the result and emit the updated state.

@ProviderFor(refreshProfilesUseCase)
final refreshProfilesUseCaseProvider = RefreshProfilesUseCaseProvider._();

/// Provides the `RefreshProfilesUseCase` wired against the active
/// [AuthRepository] (in-memory or HTTP, per `API_BASE_URL`).
///
/// The usecase only fetches the new profile list — it does not mutate
/// state. The `SessionController.refreshProfiles` orchestrator consumes
/// this provider, calls `execute()`, and then calls `replaceProfiles(...)`
/// on itself to persist the result and emit the updated state.

final class RefreshProfilesUseCaseProvider
    extends
        $FunctionalProvider<
          RefreshProfilesUseCase,
          RefreshProfilesUseCase,
          RefreshProfilesUseCase
        >
    with $Provider<RefreshProfilesUseCase> {
  /// Provides the `RefreshProfilesUseCase` wired against the active
  /// [AuthRepository] (in-memory or HTTP, per `API_BASE_URL`).
  ///
  /// The usecase only fetches the new profile list — it does not mutate
  /// state. The `SessionController.refreshProfiles` orchestrator consumes
  /// this provider, calls `execute()`, and then calls `replaceProfiles(...)`
  /// on itself to persist the result and emit the updated state.
  RefreshProfilesUseCaseProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'refreshProfilesUseCaseProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$refreshProfilesUseCaseHash();

  @$internal
  @override
  $ProviderElement<RefreshProfilesUseCase> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  RefreshProfilesUseCase create(Ref ref) {
    return refreshProfilesUseCase(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(RefreshProfilesUseCase value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<RefreshProfilesUseCase>(value),
    );
  }
}

String _$refreshProfilesUseCaseHash() =>
    r'8ce0721e4cee51fae7c8e58ff0fd5fee078ea627';
