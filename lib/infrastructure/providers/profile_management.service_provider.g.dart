// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'profile_management.service_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(profileManagementService)
final profileManagementServiceProvider = ProfileManagementServiceProvider._();

final class ProfileManagementServiceProvider
    extends
        $FunctionalProvider<
          ProfileManagementApplicationService,
          ProfileManagementApplicationService,
          ProfileManagementApplicationService
        >
    with $Provider<ProfileManagementApplicationService> {
  ProfileManagementServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'profileManagementServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$profileManagementServiceHash();

  @$internal
  @override
  $ProviderElement<ProfileManagementApplicationService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ProfileManagementApplicationService create(Ref ref) {
    return profileManagementService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ProfileManagementApplicationService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ProfileManagementApplicationService>(
        value,
      ),
    );
  }
}

String _$profileManagementServiceHash() =>
    r'963b5eac9a78ead1085faca6ff7dae7038723595';
