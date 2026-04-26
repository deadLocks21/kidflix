// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'kids_lock.service_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Returns the [KidsLockService] implementation matching the current
/// platform. The selection is evaluated once at provider creation
/// (Android → platform channel, anything else → noop). The platform
/// is constant for the lifetime of the app, so the provider does not
/// need to react to changes.

@ProviderFor(kidsLockService)
final kidsLockServiceProvider = KidsLockServiceProvider._();

/// Returns the [KidsLockService] implementation matching the current
/// platform. The selection is evaluated once at provider creation
/// (Android → platform channel, anything else → noop). The platform
/// is constant for the lifetime of the app, so the provider does not
/// need to react to changes.

final class KidsLockServiceProvider
    extends
        $FunctionalProvider<KidsLockService, KidsLockService, KidsLockService>
    with $Provider<KidsLockService> {
  /// Returns the [KidsLockService] implementation matching the current
  /// platform. The selection is evaluated once at provider creation
  /// (Android → platform channel, anything else → noop). The platform
  /// is constant for the lifetime of the app, so the provider does not
  /// need to react to changes.
  KidsLockServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'kidsLockServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$kidsLockServiceHash();

  @$internal
  @override
  $ProviderElement<KidsLockService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  KidsLockService create(Ref ref) {
    return kidsLockService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(KidsLockService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<KidsLockService>(value),
    );
  }
}

String _$kidsLockServiceHash() => r'6ab2cdde45524075eb6c2b82b20cc93e39df5b9f';
