// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'catalog.repository_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Catalog repository provider.
///
/// Selects between two implementations based on [apiBaseUrlProvider]:
///
/// - **empty** → [InMemoryCatalogRepository] — used by tests and when no
///   backend has been configured.
/// - **non-empty** → [DioCatalogRepository] consuming [dioProvider] —
///   talks to the real backend at the URL the user configured via the ⚙
///   dialog on the phone-entry page (persisted in `shared_preferences`).

@ProviderFor(catalogRepository)
final catalogRepositoryProvider = CatalogRepositoryProvider._();

/// Catalog repository provider.
///
/// Selects between two implementations based on [apiBaseUrlProvider]:
///
/// - **empty** → [InMemoryCatalogRepository] — used by tests and when no
///   backend has been configured.
/// - **non-empty** → [DioCatalogRepository] consuming [dioProvider] —
///   talks to the real backend at the URL the user configured via the ⚙
///   dialog on the phone-entry page (persisted in `shared_preferences`).

final class CatalogRepositoryProvider
    extends
        $FunctionalProvider<
          CatalogRepository,
          CatalogRepository,
          CatalogRepository
        >
    with $Provider<CatalogRepository> {
  /// Catalog repository provider.
  ///
  /// Selects between two implementations based on [apiBaseUrlProvider]:
  ///
  /// - **empty** → [InMemoryCatalogRepository] — used by tests and when no
  ///   backend has been configured.
  /// - **non-empty** → [DioCatalogRepository] consuming [dioProvider] —
  ///   talks to the real backend at the URL the user configured via the ⚙
  ///   dialog on the phone-entry page (persisted in `shared_preferences`).
  CatalogRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'catalogRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$catalogRepositoryHash();

  @$internal
  @override
  $ProviderElement<CatalogRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  CatalogRepository create(Ref ref) {
    return catalogRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CatalogRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CatalogRepository>(value),
    );
  }
}

String _$catalogRepositoryHash() => r'ad59320c9b7863b7654965f75f644a89546e543c';
