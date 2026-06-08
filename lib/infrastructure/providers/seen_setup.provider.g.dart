// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'seen_setup.provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Full movie catalogue for the "déjà vu" bulk-entry screen — films only
/// (the feature is movie-scoped at MVP, like the "Jamais vus" row).
///
/// Not `keepAlive`: the list is only needed while the setup screen is
/// mounted and should re-fetch on each visit so a freshly-added
/// catalogue entry shows up.

@ProviderFor(seenSetupMovies)
final seenSetupMoviesProvider = SeenSetupMoviesProvider._();

/// Full movie catalogue for the "déjà vu" bulk-entry screen — films only
/// (the feature is movie-scoped at MVP, like the "Jamais vus" row).
///
/// Not `keepAlive`: the list is only needed while the setup screen is
/// mounted and should re-fetch on each visit so a freshly-added
/// catalogue entry shows up.

final class SeenSetupMoviesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Movie>>,
          List<Movie>,
          FutureOr<List<Movie>>
        >
    with $FutureModifier<List<Movie>>, $FutureProvider<List<Movie>> {
  /// Full movie catalogue for the "déjà vu" bulk-entry screen — films only
  /// (the feature is movie-scoped at MVP, like the "Jamais vus" row).
  ///
  /// Not `keepAlive`: the list is only needed while the setup screen is
  /// mounted and should re-fetch on each visit so a freshly-added
  /// catalogue entry shows up.
  SeenSetupMoviesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'seenSetupMoviesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$seenSetupMoviesHash();

  @$internal
  @override
  $FutureProviderElement<List<Movie>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<Movie>> create(Ref ref) {
    return seenSetupMovies(ref);
  }
}

String _$seenSetupMoviesHash() => r'4af2585cbefe3a0651451e7c2daba66797a46580';
