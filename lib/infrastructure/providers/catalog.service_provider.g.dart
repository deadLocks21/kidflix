// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'catalog.service_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(catalogService)
final catalogServiceProvider = CatalogServiceProvider._();

final class CatalogServiceProvider
    extends
        $FunctionalProvider<
          CatalogApplicationService,
          CatalogApplicationService,
          CatalogApplicationService
        >
    with $Provider<CatalogApplicationService> {
  CatalogServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'catalogServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$catalogServiceHash();

  @$internal
  @override
  $ProviderElement<CatalogApplicationService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  CatalogApplicationService create(Ref ref) {
    return catalogService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CatalogApplicationService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CatalogApplicationService>(value),
    );
  }
}

String _$catalogServiceHash() => r'bdf570ded8f098b8c3ab3fe136bdbe34fd92f764';
