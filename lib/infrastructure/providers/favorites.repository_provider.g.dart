// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'favorites.repository_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Favorites repository provider.
///
/// - **empty / demo URL** → [InMemoryFavoritesRepository] (no backend).
/// - **real URL** → [DioFavoritesRepository], hitting the
///   `/profiles/{p}/favorites/*` endpoints documented in
///   `FAVORITES_FEATURE.md`.
///
/// `keepAlive` so the in-memory variant survives across pages — losing
/// favorites on each navigation would defeat the dev-mode persona.

@ProviderFor(favoritesRepository)
final favoritesRepositoryProvider = FavoritesRepositoryProvider._();

/// Favorites repository provider.
///
/// - **empty / demo URL** → [InMemoryFavoritesRepository] (no backend).
/// - **real URL** → [DioFavoritesRepository], hitting the
///   `/profiles/{p}/favorites/*` endpoints documented in
///   `FAVORITES_FEATURE.md`.
///
/// `keepAlive` so the in-memory variant survives across pages — losing
/// favorites on each navigation would defeat the dev-mode persona.

final class FavoritesRepositoryProvider
    extends
        $FunctionalProvider<
          FavoritesRepository,
          FavoritesRepository,
          FavoritesRepository
        >
    with $Provider<FavoritesRepository> {
  /// Favorites repository provider.
  ///
  /// - **empty / demo URL** → [InMemoryFavoritesRepository] (no backend).
  /// - **real URL** → [DioFavoritesRepository], hitting the
  ///   `/profiles/{p}/favorites/*` endpoints documented in
  ///   `FAVORITES_FEATURE.md`.
  ///
  /// `keepAlive` so the in-memory variant survives across pages — losing
  /// favorites on each navigation would defeat the dev-mode persona.
  FavoritesRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'favoritesRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$favoritesRepositoryHash();

  @$internal
  @override
  $ProviderElement<FavoritesRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  FavoritesRepository create(Ref ref) {
    return favoritesRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(FavoritesRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<FavoritesRepository>(value),
    );
  }
}

String _$favoritesRepositoryHash() =>
    r'b132784de66d71d29c1a948416a26b8bfbd5c499';
