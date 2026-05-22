// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'offline_catalog.service_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Offline counterpart of [catalogRepositoryProvider]: reconstructs a
/// movies-only catalog from the download manifest, with the active
/// profile's age filter (`ageCategory` ∪ `includedLowerAgeCategories`)
/// applied at the repository layer — mirroring the online flow where
/// the backend filters server-side via `X-Profile-Id`.
///
/// Errors when no profile is selected: the home should never be reached
/// in that state.

@ProviderFor(offlineCatalogRepository)
final offlineCatalogRepositoryProvider = OfflineCatalogRepositoryProvider._();

/// Offline counterpart of [catalogRepositoryProvider]: reconstructs a
/// movies-only catalog from the download manifest, with the active
/// profile's age filter (`ageCategory` ∪ `includedLowerAgeCategories`)
/// applied at the repository layer — mirroring the online flow where
/// the backend filters server-side via `X-Profile-Id`.
///
/// Errors when no profile is selected: the home should never be reached
/// in that state.

final class OfflineCatalogRepositoryProvider
    extends
        $FunctionalProvider<
          CatalogRepository,
          CatalogRepository,
          CatalogRepository
        >
    with $Provider<CatalogRepository> {
  /// Offline counterpart of [catalogRepositoryProvider]: reconstructs a
  /// movies-only catalog from the download manifest, with the active
  /// profile's age filter (`ageCategory` ∪ `includedLowerAgeCategories`)
  /// applied at the repository layer — mirroring the online flow where
  /// the backend filters server-side via `X-Profile-Id`.
  ///
  /// Errors when no profile is selected: the home should never be reached
  /// in that state.
  OfflineCatalogRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'offlineCatalogRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$offlineCatalogRepositoryHash();

  @$internal
  @override
  $ProviderElement<CatalogRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  CatalogRepository create(Ref ref) {
    return offlineCatalogRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CatalogRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CatalogRepository>(value),
    );
  }
}

String _$offlineCatalogRepositoryHash() =>
    r'138cf1ebe86a862225493d03ffbb11cc75da0557';

/// Offline [CatalogApplicationService]: same row-assembly logic as the
/// online service, but reads from the manifest-backed repository and
/// drops the `dynamicMinItems` gate to `0` so even a single downloaded
/// film in a given genre yields a visible row.

@ProviderFor(offlineCatalogService)
final offlineCatalogServiceProvider = OfflineCatalogServiceProvider._();

/// Offline [CatalogApplicationService]: same row-assembly logic as the
/// online service, but reads from the manifest-backed repository and
/// drops the `dynamicMinItems` gate to `0` so even a single downloaded
/// film in a given genre yields a visible row.

final class OfflineCatalogServiceProvider
    extends
        $FunctionalProvider<
          CatalogApplicationService,
          CatalogApplicationService,
          CatalogApplicationService
        >
    with $Provider<CatalogApplicationService> {
  /// Offline [CatalogApplicationService]: same row-assembly logic as the
  /// online service, but reads from the manifest-backed repository and
  /// drops the `dynamicMinItems` gate to `0` so even a single downloaded
  /// film in a given genre yields a visible row.
  OfflineCatalogServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'offlineCatalogServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$offlineCatalogServiceHash();

  @$internal
  @override
  $ProviderElement<CatalogApplicationService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  CatalogApplicationService create(Ref ref) {
    return offlineCatalogService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CatalogApplicationService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CatalogApplicationService>(value),
    );
  }
}

String _$offlineCatalogServiceHash() =>
    r'2effb48f099546ec6e19d1c106a8199d35a3d517';
