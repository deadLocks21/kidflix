// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'profile_management.repository_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Profile-management repository provider.
///
/// Currently always returns [InMemoryProfileManagementRepository]. Will
/// gain an HTTP variant when the backend is available.

@ProviderFor(profileManagementRepository)
final profileManagementRepositoryProvider =
    ProfileManagementRepositoryProvider._();

/// Profile-management repository provider.
///
/// Currently always returns [InMemoryProfileManagementRepository]. Will
/// gain an HTTP variant when the backend is available.

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
  /// Currently always returns [InMemoryProfileManagementRepository]. Will
  /// gain an HTTP variant when the backend is available.
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
    r'7d3b8d8c775d4132380868f8220deab05a50fe04';
