// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'catalog.repository_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Catalog repository provider.
///
/// Selects between two implementations based on the compile-time constant
/// `String.fromEnvironment('API_BASE_URL')`:
///
/// - **empty (default)** → [InMemoryCatalogRepository] — used by tests, by
///   `flutter run` without flag, and by anyone running offline.
/// - **non-empty** → [DioCatalogRepository] consuming [dioProvider] — used
///   to talk to the real backend, e.g.
///   `flutter run --dart-define=API_BASE_URL=http://localhost:8080`.
///
/// Switching modes requires a full rebuild — `String.fromEnvironment` is
/// evaluated at compile time, not at runtime.

@ProviderFor(catalogRepository)
final catalogRepositoryProvider = CatalogRepositoryProvider._();

/// Catalog repository provider.
///
/// Selects between two implementations based on the compile-time constant
/// `String.fromEnvironment('API_BASE_URL')`:
///
/// - **empty (default)** → [InMemoryCatalogRepository] — used by tests, by
///   `flutter run` without flag, and by anyone running offline.
/// - **non-empty** → [DioCatalogRepository] consuming [dioProvider] — used
///   to talk to the real backend, e.g.
///   `flutter run --dart-define=API_BASE_URL=http://localhost:8080`.
///
/// Switching modes requires a full rebuild — `String.fromEnvironment` is
/// evaluated at compile time, not at runtime.

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
  /// Selects between two implementations based on the compile-time constant
  /// `String.fromEnvironment('API_BASE_URL')`:
  ///
  /// - **empty (default)** → [InMemoryCatalogRepository] — used by tests, by
  ///   `flutter run` without flag, and by anyone running offline.
  /// - **non-empty** → [DioCatalogRepository] consuming [dioProvider] — used
  ///   to talk to the real backend, e.g.
  ///   `flutter run --dart-define=API_BASE_URL=http://localhost:8080`.
  ///
  /// Switching modes requires a full rebuild — `String.fromEnvironment` is
  /// evaluated at compile time, not at runtime.
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

String _$catalogRepositoryHash() => r'5d2c92eeeae712ef9018ae292f77c29f897ba55b';
