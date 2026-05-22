// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'catalog.usecases_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(listHomeCatalogUseCase)
final listHomeCatalogUseCaseProvider = ListHomeCatalogUseCaseProvider._();

final class ListHomeCatalogUseCaseProvider
    extends
        $FunctionalProvider<
          ListHomeCatalogUseCase,
          ListHomeCatalogUseCase,
          ListHomeCatalogUseCase
        >
    with $Provider<ListHomeCatalogUseCase> {
  ListHomeCatalogUseCaseProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'listHomeCatalogUseCaseProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$listHomeCatalogUseCaseHash();

  @$internal
  @override
  $ProviderElement<ListHomeCatalogUseCase> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ListHomeCatalogUseCase create(Ref ref) {
    return listHomeCatalogUseCase(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ListHomeCatalogUseCase value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ListHomeCatalogUseCase>(value),
    );
  }
}

String _$listHomeCatalogUseCaseHash() =>
    r'4c419a05e83328525eb8a489025ff432ed46311e';

@ProviderFor(refreshDownloadSnapshotsUseCase)
final refreshDownloadSnapshotsUseCaseProvider =
    RefreshDownloadSnapshotsUseCaseProvider._();

final class RefreshDownloadSnapshotsUseCaseProvider
    extends
        $FunctionalProvider<
          RefreshDownloadSnapshotsUseCase,
          RefreshDownloadSnapshotsUseCase,
          RefreshDownloadSnapshotsUseCase
        >
    with $Provider<RefreshDownloadSnapshotsUseCase> {
  RefreshDownloadSnapshotsUseCaseProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'refreshDownloadSnapshotsUseCaseProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$refreshDownloadSnapshotsUseCaseHash();

  @$internal
  @override
  $ProviderElement<RefreshDownloadSnapshotsUseCase> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  RefreshDownloadSnapshotsUseCase create(Ref ref) {
    return refreshDownloadSnapshotsUseCase(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(RefreshDownloadSnapshotsUseCase value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<RefreshDownloadSnapshotsUseCase>(
        value,
      ),
    );
  }
}

String _$refreshDownloadSnapshotsUseCaseHash() =>
    r'c3518c9404c4f6bf23470beadd93bf917bc70105';

/// Offline counterpart of [listHomeCatalogUseCaseProvider]. Same use
/// case type, but wired on top of the manifest-backed catalog service.

@ProviderFor(listOfflineHomeCatalogUseCase)
final listOfflineHomeCatalogUseCaseProvider =
    ListOfflineHomeCatalogUseCaseProvider._();

/// Offline counterpart of [listHomeCatalogUseCaseProvider]. Same use
/// case type, but wired on top of the manifest-backed catalog service.

final class ListOfflineHomeCatalogUseCaseProvider
    extends
        $FunctionalProvider<
          ListHomeCatalogUseCase,
          ListHomeCatalogUseCase,
          ListHomeCatalogUseCase
        >
    with $Provider<ListHomeCatalogUseCase> {
  /// Offline counterpart of [listHomeCatalogUseCaseProvider]. Same use
  /// case type, but wired on top of the manifest-backed catalog service.
  ListOfflineHomeCatalogUseCaseProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'listOfflineHomeCatalogUseCaseProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$listOfflineHomeCatalogUseCaseHash();

  @$internal
  @override
  $ProviderElement<ListHomeCatalogUseCase> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ListHomeCatalogUseCase create(Ref ref) {
    return listOfflineHomeCatalogUseCase(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ListHomeCatalogUseCase value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ListHomeCatalogUseCase>(value),
    );
  }
}

String _$listOfflineHomeCatalogUseCaseHash() =>
    r'b8d44fc38c30bf0ffffbf6b5dc3cab4be290cff8';

/// Session-stable seed for the home shuffle. `keepAlive` so it survives
/// across `homeCatalogRows` rebuilds — without this, every invalidation
/// (e.g. `downloadInventoryProvider` after starting a download) would
/// reshuffle every row, making the home appear to "reset" on a tap.
/// Refreshes only on full app restart.

@ProviderFor(homeShuffleSeed)
final homeShuffleSeedProvider = HomeShuffleSeedProvider._();

/// Session-stable seed for the home shuffle. `keepAlive` so it survives
/// across `homeCatalogRows` rebuilds — without this, every invalidation
/// (e.g. `downloadInventoryProvider` after starting a download) would
/// reshuffle every row, making the home appear to "reset" on a tap.
/// Refreshes only on full app restart.

final class HomeShuffleSeedProvider extends $FunctionalProvider<int, int, int>
    with $Provider<int> {
  /// Session-stable seed for the home shuffle. `keepAlive` so it survives
  /// across `homeCatalogRows` rebuilds — without this, every invalidation
  /// (e.g. `downloadInventoryProvider` after starting a download) would
  /// reshuffle every row, making the home appear to "reset" on a tap.
  /// Refreshes only on full app restart.
  HomeShuffleSeedProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'homeShuffleSeedProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$homeShuffleSeedHash();

  @$internal
  @override
  $ProviderElement<int> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  int create(Ref ref) {
    return homeShuffleSeed(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(int value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<int>(value),
    );
  }
}

String _$homeShuffleSeedHash() => r'e0ae0b309db17e191fe4589623432c83f869b68e';

/// Builds the list of homepage rows for the active profile. Re-computes
/// automatically when the session transitions to a different profile,
/// when the download inventory changes (new download, mark as cache,
/// deletion) so the "Téléchargés" row stays in sync, and when the
/// connectivity state flips (online ↔ offline) so the source swaps.
///
/// Source selection:
/// - **Online** → standard [listHomeCatalogUseCaseProvider], hits the
///   backend. If the network call throws, we fall back to the offline
///   use case so the user still sees their downloaded items rather than
///   an error screen.
/// - **Offline** → [listOfflineHomeCatalogUseCaseProvider], reconstructs
///   rows from the download manifest. Movies only (cf.
///   `ManifestBackedCatalogRepository` doc).
///
/// Expects the session to be in [ProfileSelected] — the router ensures the
/// home page is only mounted in that state.

@ProviderFor(homeCatalogRows)
final homeCatalogRowsProvider = HomeCatalogRowsProvider._();

/// Builds the list of homepage rows for the active profile. Re-computes
/// automatically when the session transitions to a different profile,
/// when the download inventory changes (new download, mark as cache,
/// deletion) so the "Téléchargés" row stays in sync, and when the
/// connectivity state flips (online ↔ offline) so the source swaps.
///
/// Source selection:
/// - **Online** → standard [listHomeCatalogUseCaseProvider], hits the
///   backend. If the network call throws, we fall back to the offline
///   use case so the user still sees their downloaded items rather than
///   an error screen.
/// - **Offline** → [listOfflineHomeCatalogUseCaseProvider], reconstructs
///   rows from the download manifest. Movies only (cf.
///   `ManifestBackedCatalogRepository` doc).
///
/// Expects the session to be in [ProfileSelected] — the router ensures the
/// home page is only mounted in that state.

final class HomeCatalogRowsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<CatalogRowDto>>,
          List<CatalogRowDto>,
          FutureOr<List<CatalogRowDto>>
        >
    with
        $FutureModifier<List<CatalogRowDto>>,
        $FutureProvider<List<CatalogRowDto>> {
  /// Builds the list of homepage rows for the active profile. Re-computes
  /// automatically when the session transitions to a different profile,
  /// when the download inventory changes (new download, mark as cache,
  /// deletion) so the "Téléchargés" row stays in sync, and when the
  /// connectivity state flips (online ↔ offline) so the source swaps.
  ///
  /// Source selection:
  /// - **Online** → standard [listHomeCatalogUseCaseProvider], hits the
  ///   backend. If the network call throws, we fall back to the offline
  ///   use case so the user still sees their downloaded items rather than
  ///   an error screen.
  /// - **Offline** → [listOfflineHomeCatalogUseCaseProvider], reconstructs
  ///   rows from the download manifest. Movies only (cf.
  ///   `ManifestBackedCatalogRepository` doc).
  ///
  /// Expects the session to be in [ProfileSelected] — the router ensures the
  /// home page is only mounted in that state.
  HomeCatalogRowsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'homeCatalogRowsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$homeCatalogRowsHash();

  @$internal
  @override
  $FutureProviderElement<List<CatalogRowDto>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<CatalogRowDto>> create(Ref ref) {
    return homeCatalogRows(ref);
  }
}

String _$homeCatalogRowsHash() => r'5c9ab5301800fb69b0791d51c43a82443d945e15';
