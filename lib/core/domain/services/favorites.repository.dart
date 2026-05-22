import 'package:kidflix/core/domain/model/favorite.dart';

/// Contract for persisting and retrieving a profile's "Ma liste" entries
/// across both movies and series.
///
/// The four mutation methods are typed by kind because call sites
/// always know statically what they need (a card or a detail modal
/// holds either a `Movie` or a `Series`, never an arbitrary
/// `CatalogItem`). All four are idempotent server-side per
/// `FAVORITES_FEATURE.md`: calling `addMovie` on an already-favorited
/// pair is a 204 no-op, calling `removeMovie` on an unknown pair is
/// also a 204 no-op (the spec explicitly forbids `404` on `DELETE`).
///
/// Implementations live in `lib/infrastructure/favorites/`.
abstract interface class FavoritesRepository {
  /// Returns every favorite (movies AND series) recorded for
  /// [profileId] in an implementation-defined order. Empty list when
  /// none exists.
  Future<List<Favorite>> listForProfile(String profileId);

  /// Adds a movie to the profile's favorites. Idempotent.
  Future<void> addMovie({required String profileId, required String movieId});

  /// Removes a movie from the profile's favorites. Idempotent.
  Future<void> removeMovie({
    required String profileId,
    required String movieId,
  });

  /// Adds a series to the profile's favorites. Idempotent.
  Future<void> addSeries({required String profileId, required String seriesId});

  /// Removes a series from the profile's favorites. Idempotent.
  Future<void> removeSeries({
    required String profileId,
    required String seriesId,
  });
}
