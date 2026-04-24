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

/// Builds the list of homepage rows for the active profile. Re-computes
/// automatically when the session transitions to a different profile.
///
/// Expects the session to be in [ProfileSelected] — the router ensures the
/// home page is only mounted in that state.

@ProviderFor(homeCatalogRows)
final homeCatalogRowsProvider = HomeCatalogRowsProvider._();

/// Builds the list of homepage rows for the active profile. Re-computes
/// automatically when the session transitions to a different profile.
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
  /// automatically when the session transitions to a different profile.
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

String _$homeCatalogRowsHash() => r'9b6b315e813fbda643a2ae0f2d282f695eb5895c';
