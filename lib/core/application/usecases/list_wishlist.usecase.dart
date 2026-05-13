import 'package:kidflix/core/application/dtos/wishlist_entry.dto.dart';
import 'package:kidflix/core/domain/model/watch_progress.dart';
import 'package:kidflix/core/domain/model/wishlist_entry.dart';
import 'package:kidflix/core/domain/services/watch_progress.repository.dart';
import 'package:kidflix/core/domain/services/wishlist.repository.dart';

/// Fetches the foyer's wishlist, cross-references it against the
/// foyer's watch progress, and projects each survivor to its UI DTO
/// with a [WishlistCategory] bucket.
///
/// The filter is unchanged: only `status == PLANNED` entries survive —
/// `WATCHING / HOLD / FINISHED / DROPPED` (Watcharr-side statuses) are
/// non-actionable for this page. The new responsibility is to
/// **bucket** the survivors into three categories based on the
/// catalog crossing + the watch progress of every profile in the
/// foyer.
///
/// Categorisation rule :
///
/// - Not in catalog → [WishlistCategory.toAcquire].
/// - In catalog, kind = movie, at least one profile has a
///   `MovieProgress` with `completed = true` for the resolved
///   `catalogId` → [WishlistCategory.watched].
/// - In catalog, kind = movie, otherwise → [WishlistCategory.toWatch].
/// - In catalog, kind = series → [WishlistCategory.toWatch] (no
///   aggregate "watched" signal for series in v1 — episode-level
///   progress is granular but the wishlist tracks the series as a
///   single unit).
///
/// Watch progress fetching is parallelised across profile ids — each
/// profile yields a `listForProfile` call. A failure on any individual
/// fetch makes the whole use case fail (caller surfaces an error
/// banner) ; this is a coarse-grained policy that fits the keepAlive
/// controller and the parent-only access pattern.
///
/// Sort: alphabetical by title within each bucket (case-insensitive).
/// The page renders buckets in the order
/// `toAcquire → toWatch → watched`, hiding empty ones.
class ListWishlistUseCase {
  final WishlistRepository _wishlistRepo;
  final WatchProgressRepository _progressRepo;

  const ListWishlistUseCase({
    required WishlistRepository wishlistRepo,
    required WatchProgressRepository progressRepo,
  })  : _wishlistRepo = wishlistRepo,
        _progressRepo = progressRepo;

  /// Fetches and categorises the wishlist.
  ///
  /// [profileIds] must list every profile in the active foyer (the
  /// session controller has them under `session.profiles`). An empty
  /// list short-circuits the progress lookup — all in-catalog entries
  /// fall in [WishlistCategory.toWatch].
  Future<List<WishlistEntryDto>> execute({
    required List<String> profileIds,
  }) async {
    final entries = await _wishlistRepo.list();
    final planned = entries
        .where((e) => e.status == WatchedStatus.planned)
        .toList()
      ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    if (planned.isEmpty) return const [];

    final watchedMovieIds = await _resolveWatchedMovieIds(profileIds);

    return planned.map((entry) {
      return WishlistEntryDto(
        watcharrId: entry.watcharrId,
        tmdbId: entry.tmdbId,
        kind: entry.kind,
        title: entry.title,
        year: entry.year,
        posterUrl: entry.posterUrl,
        status: entry.status,
        rating: entry.rating,
        availableInCatalog: entry.availableInCatalog,
        catalogId: entry.catalogId,
        category: _resolveCategory(entry, watchedMovieIds),
      );
    }).toList(growable: false);
  }

  /// Aggregates `(profile, movie) → completed` across every profile
  /// in the foyer into a single set of `movieId`. A movie is
  /// considered "watched" by the foyer as soon as **any** profile has
  /// completed it.
  Future<Set<String>> _resolveWatchedMovieIds(List<String> profileIds) async {
    if (profileIds.isEmpty) return const {};
    final perProfile = await Future.wait(
      profileIds.map(_progressRepo.listForProfile),
    );
    final ids = <String>{};
    for (final list in perProfile) {
      for (final progress in list) {
        if (progress is MovieProgress && progress.completed) {
          ids.add(progress.movieId);
        }
      }
    }
    return ids;
  }

  WishlistCategory _resolveCategory(
    WishlistEntry entry,
    Set<String> watchedMovieIds,
  ) {
    if (!entry.availableInCatalog) {
      return WishlistCategory.toAcquire;
    }
    if (entry.kind == WishlistItemKind.series) {
      // No aggregate "watched" semantics for series in v1.
      return WishlistCategory.toWatch;
    }
    final catalogId = entry.catalogId;
    if (catalogId != null && watchedMovieIds.contains(catalogId)) {
      return WishlistCategory.watched;
    }
    return WishlistCategory.toWatch;
  }
}
