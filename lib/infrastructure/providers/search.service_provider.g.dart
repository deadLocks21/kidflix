// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'search.service_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(searchService)
final searchServiceProvider = SearchServiceProvider._();

final class SearchServiceProvider
    extends
        $FunctionalProvider<
          SearchApplicationService,
          SearchApplicationService,
          SearchApplicationService
        >
    with $Provider<SearchApplicationService> {
  SearchServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'searchServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$searchServiceHash();

  @$internal
  @override
  $ProviderElement<SearchApplicationService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  SearchApplicationService create(Ref ref) {
    return searchService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SearchApplicationService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SearchApplicationService>(value),
    );
  }
}

String _$searchServiceHash() => r'6b4cb5883d9661b6f5bf412848f39ba31e6c8b36';
