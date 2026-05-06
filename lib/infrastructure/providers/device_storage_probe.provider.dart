import 'package:kidflix/core/domain/services/device_storage_probe.dart';
import 'package:kidflix/infrastructure/downloads/io_device_storage_probe.dart';
import 'package:kidflix/infrastructure/providers/download.repository_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'device_storage_probe.provider.g.dart';

/// Singleton storage probe combining repository's `totalBytesOnDisk`
/// (for `appDownloadsBytes`) and the platform plugin (for
/// `deviceFreeBytes`). Returns `null` device-side when the plugin is
/// unavailable — never throws.
@Riverpod(keepAlive: true)
DeviceStorageProbe deviceStorageProbe(Ref ref) {
  return IoDeviceStorageProbe(
    repository: ref.watch(downloadRepositoryProvider),
  );
}
