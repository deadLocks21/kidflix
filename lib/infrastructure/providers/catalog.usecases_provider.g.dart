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
    r'663d9202b322f2f1bdc01a829470062cd368af14';

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
/// and when the download inventory changes (new download, mark as
/// cache, deletion) so the "Téléchargés" row stays in sync.
///
/// Expects the session to be in [ProfileSelected] — the router ensures the
/// home page is only mounted in that state.

@ProviderFor(homeCatalogRows)
final homeCatalogRowsProvider = HomeCatalogRowsProvider._();

/// Builds the list of homepage rows for the active profile. Re-computes
/// automatically when the session transitions to a different profile,
/// and when the download inventory changes (new download, mark as
/// cache, deletion) so the "Téléchargés" row stays in sync.
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
  /// and when the download inventory changes (new download, mark as
  /// cache, deletion) so the "Téléchargés" row stays in sync.
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

String _$homeCatalogRowsHash() => r'3c24c94b8f1548bdb4faf1e8c2c8cfd1afecb3d3';
