// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'download_manifest_store.provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Singleton store backing the download manifest sidecar at
/// `${applicationDocumentsDirectory}/downloads/manifest.json`.
///
/// `keepAlive: true` so the in-memory cache populated on first access
/// is reused across providers/repositories. Tests override via the
/// standard Riverpod mechanism.

@ProviderFor(downloadManifestStore)
final downloadManifestStoreProvider = DownloadManifestStoreProvider._();

/// Singleton store backing the download manifest sidecar at
/// `${applicationDocumentsDirectory}/downloads/manifest.json`.
///
/// `keepAlive: true` so the in-memory cache populated on first access
/// is reused across providers/repositories. Tests override via the
/// standard Riverpod mechanism.

final class DownloadManifestStoreProvider
    extends
        $FunctionalProvider<
          DownloadManifestStore,
          DownloadManifestStore,
          DownloadManifestStore
        >
    with $Provider<DownloadManifestStore> {
  /// Singleton store backing the download manifest sidecar at
  /// `${applicationDocumentsDirectory}/downloads/manifest.json`.
  ///
  /// `keepAlive: true` so the in-memory cache populated on first access
  /// is reused across providers/repositories. Tests override via the
  /// standard Riverpod mechanism.
  DownloadManifestStoreProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'downloadManifestStoreProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$downloadManifestStoreHash();

  @$internal
  @override
  $ProviderElement<DownloadManifestStore> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  DownloadManifestStore create(Ref ref) {
    return downloadManifestStore(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DownloadManifestStore value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DownloadManifestStore>(value),
    );
  }
}

String _$downloadManifestStoreHash() =>
    r'88f07a4f4acbde150d9bf2c54c975c99cef33f74';
