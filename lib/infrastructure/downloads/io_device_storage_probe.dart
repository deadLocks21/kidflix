import 'package:disk_space_plus/disk_space_plus.dart';
import 'package:kidflix/core/domain/services/device_storage_probe.dart';
import 'package:kidflix/core/domain/services/download.repository.dart';

/// Default platform implementation of [DeviceStorageProbe].
///
/// `appDownloadsBytes` delegates to the active [DownloadRepository] so
/// the inventory layer remains the single source of truth for the byte
/// count. `deviceFreeBytes` calls [DiskSpacePlus.getFreeDiskSpace] and
/// converts the MB-resolution result to bytes; any thrown plugin error
/// resolves to `null` (the contract).
class IoDeviceStorageProbe implements DeviceStorageProbe {
  final DownloadRepository _repository;
  final DiskSpacePlus _diskSpace;

  IoDeviceStorageProbe({
    required DownloadRepository repository,
    DiskSpacePlus? diskSpace,
  })  : _repository = repository,
        _diskSpace = diskSpace ?? DiskSpacePlus();

  @override
  Future<int> appDownloadsBytes() async {
    try {
      return await _repository.totalBytesOnDisk();
    } catch (_) {
      return 0;
    }
  }

  @override
  Future<int?> deviceFreeBytes() async {
    try {
      final freeMb = await _diskSpace.getFreeDiskSpace;
      if (freeMb == null) return null;
      return (freeMb * 1024 * 1024).round();
    } catch (_) {
      return null;
    }
  }
}
