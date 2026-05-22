// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'search.usecase_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(searchMoviesUseCase)
final searchMoviesUseCaseProvider = SearchMoviesUseCaseProvider._();

final class SearchMoviesUseCaseProvider
    extends
        $FunctionalProvider<
          SearchMoviesUseCase,
          SearchMoviesUseCase,
          SearchMoviesUseCase
        >
    with $Provider<SearchMoviesUseCase> {
  SearchMoviesUseCaseProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'searchMoviesUseCaseProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$searchMoviesUseCaseHash();

  @$internal
  @override
  $ProviderElement<SearchMoviesUseCase> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  SearchMoviesUseCase create(Ref ref) {
    return searchMoviesUseCase(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SearchMoviesUseCase value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SearchMoviesUseCase>(value),
    );
  }
}

String _$searchMoviesUseCaseHash() =>
    r'1cfa50eb758b1e2b84d9e213960c9900317d06a3';

/// Returns the alphabetically-sorted list of catalog items (movies and
/// series mixed) matching [debouncedQuery] for the currently active
/// profile.
///
/// Short-circuits to an empty list when the trimmed query is shorter than
/// 2 characters or when no profile is active — the UI enforces the same
/// preconditions but this provider is the final fail-safe.

@ProviderFor(searchResults)
final searchResultsProvider = SearchResultsFamily._();

/// Returns the alphabetically-sorted list of catalog items (movies and
/// series mixed) matching [debouncedQuery] for the currently active
/// profile.
///
/// Short-circuits to an empty list when the trimmed query is shorter than
/// 2 characters or when no profile is active — the UI enforces the same
/// preconditions but this provider is the final fail-safe.

final class SearchResultsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<CatalogItemDto>>,
          List<CatalogItemDto>,
          FutureOr<List<CatalogItemDto>>
        >
    with
        $FutureModifier<List<CatalogItemDto>>,
        $FutureProvider<List<CatalogItemDto>> {
  /// Returns the alphabetically-sorted list of catalog items (movies and
  /// series mixed) matching [debouncedQuery] for the currently active
  /// profile.
  ///
  /// Short-circuits to an empty list when the trimmed query is shorter than
  /// 2 characters or when no profile is active — the UI enforces the same
  /// preconditions but this provider is the final fail-safe.
  SearchResultsProvider._({
    required SearchResultsFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'searchResultsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$searchResultsHash();

  @override
  String toString() {
    return r'searchResultsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<CatalogItemDto>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<CatalogItemDto>> create(Ref ref) {
    final argument = this.argument as String;
    return searchResults(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is SearchResultsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$searchResultsHash() => r'd3bacb04b2da605973f26cae6b16f2646de2765e';

/// Returns the alphabetically-sorted list of catalog items (movies and
/// series mixed) matching [debouncedQuery] for the currently active
/// profile.
///
/// Short-circuits to an empty list when the trimmed query is shorter than
/// 2 characters or when no profile is active — the UI enforces the same
/// preconditions but this provider is the final fail-safe.

final class SearchResultsFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<CatalogItemDto>>, String> {
  SearchResultsFamily._()
    : super(
        retry: null,
        name: r'searchResultsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Returns the alphabetically-sorted list of catalog items (movies and
  /// series mixed) matching [debouncedQuery] for the currently active
  /// profile.
  ///
  /// Short-circuits to an empty list when the trimmed query is shorter than
  /// 2 characters or when no profile is active — the UI enforces the same
  /// preconditions but this provider is the final fail-safe.

  SearchResultsProvider call(String debouncedQuery) =>
      SearchResultsProvider._(argument: debouncedQuery, from: this);

  @override
  String toString() => r'searchResultsProvider';
}
