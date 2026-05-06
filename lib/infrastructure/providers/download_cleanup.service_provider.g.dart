// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'download_cleanup.service_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Singleton cleanup service backed by the active [DownloadRepository].
///
/// Consumed by `RunStartupCacheCleanupUseCase` at app boot.

@ProviderFor(downloadCleanupService)
final downloadCleanupServiceProvider = DownloadCleanupServiceProvider._();

/// Singleton cleanup service backed by the active [DownloadRepository].
///
/// Consumed by `RunStartupCacheCleanupUseCase` at app boot.

final class DownloadCleanupServiceProvider
    extends
        $FunctionalProvider<
          DownloadCleanupService,
          DownloadCleanupService,
          DownloadCleanupService
        >
    with $Provider<DownloadCleanupService> {
  /// Singleton cleanup service backed by the active [DownloadRepository].
  ///
  /// Consumed by `RunStartupCacheCleanupUseCase` at app boot.
  DownloadCleanupServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'downloadCleanupServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$downloadCleanupServiceHash();

  @$internal
  @override
  $ProviderElement<DownloadCleanupService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  DownloadCleanupService create(Ref ref) {
    return downloadCleanupService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DownloadCleanupService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DownloadCleanupService>(value),
    );
  }
}

String _$downloadCleanupServiceHash() =>
    r'330886c16f6af535b823a18e0fa5b301f47d1c0e';
