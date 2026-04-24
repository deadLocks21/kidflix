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
    r'fdc799de86e114d18895ec4c3750a1eb1f01a039';

/// Returns the alphabetically-sorted list of movies matching
/// [debouncedQuery] for the currently active profile.
///
/// Short-circuits to an empty list when the trimmed query is shorter than
/// 2 characters or when no profile is active — the UI enforces the same
/// preconditions but this provider is the final fail-safe.

@ProviderFor(searchResults)
final searchResultsProvider = SearchResultsFamily._();

/// Returns the alphabetically-sorted list of movies matching
/// [debouncedQuery] for the currently active profile.
///
/// Short-circuits to an empty list when the trimmed query is shorter than
/// 2 characters or when no profile is active — the UI enforces the same
/// preconditions but this provider is the final fail-safe.

final class SearchResultsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<MovieDto>>,
          List<MovieDto>,
          FutureOr<List<MovieDto>>
        >
    with $FutureModifier<List<MovieDto>>, $FutureProvider<List<MovieDto>> {
  /// Returns the alphabetically-sorted list of movies matching
  /// [debouncedQuery] for the currently active profile.
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
  $FutureProviderElement<List<MovieDto>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<MovieDto>> create(Ref ref) {
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

String _$searchResultsHash() => r'b5f08557e783e9f3a36789218ce9eb7a36e390ee';

/// Returns the alphabetically-sorted list of movies matching
/// [debouncedQuery] for the currently active profile.
///
/// Short-circuits to an empty list when the trimmed query is shorter than
/// 2 characters or when no profile is active — the UI enforces the same
/// preconditions but this provider is the final fail-safe.

final class SearchResultsFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<MovieDto>>, String> {
  SearchResultsFamily._()
    : super(
        retry: null,
        name: r'searchResultsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Returns the alphabetically-sorted list of movies matching
  /// [debouncedQuery] for the currently active profile.
  ///
  /// Short-circuits to an empty list when the trimmed query is shorter than
  /// 2 characters or when no profile is active — the UI enforces the same
  /// preconditions but this provider is the final fail-safe.

  SearchResultsProvider call(String debouncedQuery) =>
      SearchResultsProvider._(argument: debouncedQuery, from: this);

  @override
  String toString() => r'searchResultsProvider';
}
