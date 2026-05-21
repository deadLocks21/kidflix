/// Domain service that exposes storage usage at two levels:
///
/// * [appDownloadsBytes] — bytes consumed by the Kidflix downloads
///   directory (sum of all media and `.partial` files). Returns `0`
///   when the directory is empty or absent. Never throws.
/// * [deviceFreeBytes] — bytes free on the volume that hosts the app's
///   documents directory. Returns `null` when the platform cannot
///   provide it (no plugin, plugin error, unsupported OS). Never throws.
///
/// The service is intentionally minimal: the manager page consumes its
/// output verbatim ("Kidflix occupe X · libre sur l'appareil : Y").
///
/// Implementations live in `lib/infrastructure/downloads/`.
abstract interface class DeviceStorageProbe {
  /// Total bytes consumed by the downloads directory under
  /// `${applicationDocumentsDirectory}/downloads/`.
  Future<int> appDownloadsBytes();

  /// Bytes free on the device's documents volume, or `null` when the
  /// platform cannot answer.
  Future<int?> deviceFreeBytes();
}
