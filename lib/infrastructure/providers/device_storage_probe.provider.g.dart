// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'device_storage_probe.provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Singleton storage probe combining repository's `totalBytesOnDisk`
/// (for `appDownloadsBytes`) and the platform plugin (for
/// `deviceFreeBytes`). Returns `null` device-side when the plugin is
/// unavailable — never throws.

@ProviderFor(deviceStorageProbe)
final deviceStorageProbeProvider = DeviceStorageProbeProvider._();

/// Singleton storage probe combining repository's `totalBytesOnDisk`
/// (for `appDownloadsBytes`) and the platform plugin (for
/// `deviceFreeBytes`). Returns `null` device-side when the plugin is
/// unavailable — never throws.

final class DeviceStorageProbeProvider
    extends
        $FunctionalProvider<
          DeviceStorageProbe,
          DeviceStorageProbe,
          DeviceStorageProbe
        >
    with $Provider<DeviceStorageProbe> {
  /// Singleton storage probe combining repository's `totalBytesOnDisk`
  /// (for `appDownloadsBytes`) and the platform plugin (for
  /// `deviceFreeBytes`). Returns `null` device-side when the plugin is
  /// unavailable — never throws.
  DeviceStorageProbeProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'deviceStorageProbeProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$deviceStorageProbeHash();

  @$internal
  @override
  $ProviderElement<DeviceStorageProbe> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  DeviceStorageProbe create(Ref ref) {
    return deviceStorageProbe(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DeviceStorageProbe value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DeviceStorageProbe>(value),
    );
  }
}

String _$deviceStorageProbeHash() =>
    r'8986bc11891a8ca7c6f2ccadc73eb45c5cfd616a';
