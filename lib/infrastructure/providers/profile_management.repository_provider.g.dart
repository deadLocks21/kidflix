// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'profile_management.repository_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Profile-management repository provider.
///
/// Selects between two implementations based on [apiBaseUrlProvider]:
///
/// - **empty** → [InMemoryProfileManagementRepository] — used by tests and
///   when no backend has been configured.
/// - **non-empty** → [DioProfileManagementRepository] consuming [dioProvider]
///   — talks to the real backend at the URL the user configured via the
///   ⚙ dialog on the phone-entry page (persisted in `shared_preferences`).
///
/// The selection MUST stay consistent with `authRepositoryProvider` —
/// both watch the same [apiBaseUrlProvider].

@ProviderFor(profileManagementRepository)
final profileManagementRepositoryProvider =
    ProfileManagementRepositoryProvider._();

/// Profile-management repository provider.
///
/// Selects between two implementations based on [apiBaseUrlProvider]:
///
/// - **empty** → [InMemoryProfileManagementRepository] — used by tests and
///   when no backend has been configured.
/// - **non-empty** → [DioProfileManagementRepository] consuming [dioProvider]
///   — talks to the real backend at the URL the user configured via the
///   ⚙ dialog on the phone-entry page (persisted in `shared_preferences`).
///
/// The selection MUST stay consistent with `authRepositoryProvider` —
/// both watch the same [apiBaseUrlProvider].

final class ProfileManagementRepositoryProvider
    extends
        $FunctionalProvider<
          ProfileManagementRepository,
          ProfileManagementRepository,
          ProfileManagementRepository
        >
    with $Provider<ProfileManagementRepository> {
  /// Profile-management repository provider.
  ///
  /// Selects between two implementations based on [apiBaseUrlProvider]:
  ///
  /// - **empty** → [InMemoryProfileManagementRepository] — used by tests and
  ///   when no backend has been configured.
  /// - **non-empty** → [DioProfileManagementRepository] consuming [dioProvider]
  ///   — talks to the real backend at the URL the user configured via the
  ///   ⚙ dialog on the phone-entry page (persisted in `shared_preferences`).
  ///
  /// The selection MUST stay consistent with `authRepositoryProvider` —
  /// both watch the same [apiBaseUrlProvider].
  ProfileManagementRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'profileManagementRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$profileManagementRepositoryHash();

  @$internal
  @override
  $ProviderElement<ProfileManagementRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ProfileManagementRepository create(Ref ref) {
    return profileManagementRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ProfileManagementRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ProfileManagementRepository>(value),
    );
  }
}

String _$profileManagementRepositoryHash() =>
    r'e73ba8dfeb7979c8ff55978281c114f04be07c9c';
