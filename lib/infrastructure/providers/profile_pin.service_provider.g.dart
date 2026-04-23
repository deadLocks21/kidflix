// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'profile_pin.service_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(profilePinService)
final profilePinServiceProvider = ProfilePinServiceProvider._();

final class ProfilePinServiceProvider
    extends
        $FunctionalProvider<
          ProfilePinService,
          ProfilePinService,
          ProfilePinService
        >
    with $Provider<ProfilePinService> {
  ProfilePinServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'profilePinServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$profilePinServiceHash();

  @$internal
  @override
  $ProviderElement<ProfilePinService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ProfilePinService create(Ref ref) {
    return profilePinService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ProfilePinService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ProfilePinService>(value),
    );
  }
}

String _$profilePinServiceHash() => r'cfee2caf4275fc4d2c7664a8a76b790df5ff5ef4';
