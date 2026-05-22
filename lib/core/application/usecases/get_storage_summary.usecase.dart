import 'package:kidflix/core/application/services/logger_application.service.dart';
import 'package:kidflix/core/domain/model/download_inventory_record.dart';
import 'package:kidflix/core/domain/model/download_kind.dart';
import 'package:kidflix/core/domain/services/device_storage_probe.dart';
import 'package:kidflix/core/domain/services/download.repository.dart';

class StorageSummary {
  final int appDownloadsBytes;
  final int? deviceFreeBytes;
  final int downloadsCount;
  final int cacheCount;

  const StorageSummary({
    required this.appDownloadsBytes,
    required this.deviceFreeBytes,
    required this.downloadsCount,
    required this.cacheCount,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StorageSummary &&
          other.appDownloadsBytes == appDownloadsBytes &&
          other.deviceFreeBytes == deviceFreeBytes &&
          other.downloadsCount == downloadsCount &&
          other.cacheCount == cacheCount);

  @override
  int get hashCode => Object.hash(
    appDownloadsBytes,
    deviceFreeBytes,
    downloadsCount,
    cacheCount,
  );

  @override
  String toString() =>
      'StorageSummary(app: $appDownloadsBytes, free: $deviceFreeBytes, '
      'downloads: $downloadsCount, cache: $cacheCount)';
}

/// Seuil sous lequel l'espace disque libre est considéré comme faible.
/// Valeur défendable choisie pour l'observabilité (< 500 Mo).
const int lowFreeStorageThresholdBytes = 500 * 1024 * 1024;

/// Aggregates storage info for the manager page header. Probe + listAll
/// run in parallel so the page renders fast.
class GetStorageSummaryUseCase {
  final DeviceStorageProbe _probe;
  final DownloadRepository _repository;
  final LoggerApplicationService _logger;

  const GetStorageSummaryUseCase({
    required DeviceStorageProbe probe,
    required DownloadRepository repository,
    required LoggerApplicationService logger,
  }) : _probe = probe,
       _repository = repository,
       _logger = logger;

  Future<StorageSummary> execute() async {
    final appBytesF = _probe.appDownloadsBytes();
    final freeBytesF = _probe.deviceFreeBytes();
    final inventoryF = _repository.listAll();
    final appBytes = await appBytesF;
    final freeBytes = await freeBytesF;
    final inventory = await inventoryF;

    var downloads = 0;
    var cache = 0;
    for (final DownloadInventoryRecord r in inventory) {
      if (r.kind == DownloadKind.download) {
        downloads++;
      } else {
        cache++;
      }
    }

    if (freeBytes != null && freeBytes < lowFreeStorageThresholdBytes) {
      await _logger.warn(
        'storage.low',
        attrs: {
          'free.bytes': freeBytes,
          'threshold.bytes': lowFreeStorageThresholdBytes,
          'app.downloads.bytes': appBytes,
        },
      );
    }

    return StorageSummary(
      appDownloadsBytes: appBytes,
      deviceFreeBytes: freeBytes,
      downloadsCount: downloads,
      cacheCount: cache,
    );
  }
}
