import 'package:kidflix/core/domain/model/favorite.dart';
import 'package:kidflix/core/domain/services/favorites.repository.dart';

/// RAM-only [FavoritesRepository] used in dev / web / tests.
///
/// Entries are lost at app restart — acceptable for the in-memory base
/// URL. The HTTP replacement preserves the same contract.
///
/// Two maps keyed on `(profileId, mediaId)` — one per kind — so that
/// a `MovieFavorite(profileId: 'p', movieId: 'x')` and a
/// `SeriesFavorite(profileId: 'p', seriesId: 'x')` coexist
/// independently, matching the server-side composite key
/// `(profile_id, media_kind, media_id)`.
///
/// All four mutation methods are idempotent: adding a pair twice keeps
/// the original `createdAt` (matches the server's `PUT` semantics —
/// `created_at` is **not** refreshed on a no-op `PUT`).
class InMemoryFavoritesRepository implements FavoritesRepository {
  final Map<String, MovieFavorite> _movies = {};
  final Map<String, SeriesFavorite> _series = {};

  String _key(String profileId, String mediaId) => '$profileId|$mediaId';

  @override
  Future<List<Favorite>> listForProfile(String profileId) async {
    final movies = _movies.values.where((f) => f.profileId == profileId);
    final series = _series.values.where((f) => f.profileId == profileId);
    return <Favorite>[...movies, ...series];
  }

  @override
  Future<void> addMovie({
    required String profileId,
    required String movieId,
  }) async {
    _movies.putIfAbsent(
      _key(profileId, movieId),
      () => MovieFavorite(
        profileId: profileId,
        movieId: movieId,
        createdAt: DateTime.now().toUtc(),
      ),
    );
  }

  @override
  Future<void> removeMovie({
    required String profileId,
    required String movieId,
  }) async {
    _movies.remove(_key(profileId, movieId));
  }

  @override
  Future<void> addSeries({
    required String profileId,
    required String seriesId,
  }) async {
    _series.putIfAbsent(
      _key(profileId, seriesId),
      () => SeriesFavorite(
        profileId: profileId,
        seriesId: seriesId,
        createdAt: DateTime.now().toUtc(),
      ),
    );
  }

  @override
  Future<void> removeSeries({
    required String profileId,
    required String seriesId,
  }) async {
    _series.remove(_key(profileId, seriesId));
  }
}
