import 'package:kidflix/core/domain/exceptions/wishlist_entry_already_exists.exception.dart';
import 'package:kidflix/core/domain/model/wishlist_entry.dart';
import 'package:kidflix/core/domain/model/wishlist_search_result.dart';
import 'package:kidflix/core/domain/services/wishlist.repository.dart';
import 'package:kidflix/shared/text_normalization.dart';

/// RAM-only [WishlistRepository] used in dev / web / tests.
///
/// Seeds a handful of fictional wishlist entries spanning both kinds
/// and both crossing states (available / not available) so the UI is
/// exercisable without a backend or a real Watcharr instance.
///
/// Cross-checks against the seeded catalog (`InMemoryCatalogRepository`)
/// are stubbed via the [availableCatalogIds] map below — flip an entry
/// to "available" by adding its `tmdbId` to the map with the matching
/// catalog id. Not wired automatically because the in-memory catalog
/// seed doesn't carry `tmdbId` today (the field is internal per
/// `API.md`); this is a UI fixture, not a faithful simulation.
///
/// All mutations affect the seed in place and survive across calls
/// during the same app run — like every `InMemory*` repository in the
/// codebase, the data is lost at app restart.
class InMemoryWishlistRepository implements WishlistRepository {
  /// Pre-resolved crossing fixtures: `tmdbId` → catalog id. Anything
  /// not in this map is rendered as "not yet in the catalog". Kept
  /// private — callers should never reach into this fixture.
  static const Map<int, _CatalogHit> _availableCatalogIds = {
    // Pretend "Big Buck Bunny" (tmdb 10378) is already in the kdrive
    // catalog — matches the catalog seed in `InMemoryCatalogRepository`.
    10378: _CatalogHit(WishlistItemKind.movie, 'big-buck-bunny'),
  };

  final List<WishlistEntry> _entries = _seed();

  @override
  Future<List<WishlistEntry>> list() async {
    return List.unmodifiable(_entries);
  }

  @override
  Future<WishlistEntry> updateStatus({
    required int watcharrId,
    required WatchedStatus status,
  }) async {
    final index = _entries.indexWhere((e) => e.watcharrId == watcharrId);
    if (index < 0) {
      throw StateError(
        'InMemoryWishlistRepository: no entry with watcharrId=$watcharrId',
      );
    }
    final updated = _entries[index].copyWith(status: status);
    _entries[index] = updated;
    return updated;
  }

  @override
  Future<void> remove(int watcharrId) async {
    _entries.removeWhere((e) => e.watcharrId == watcharrId);
  }

  @override
  Future<List<WishlistSearchResult>> search(String query) async {
    final normalised = normalizeForSearch(query);
    final wishlistTmdbIds = _entries.map((e) => e.tmdbId).toSet();
    return _searchFixtures
        .where((f) => normalizeForSearch(f.title).contains(normalised))
        .map((f) {
          final hit = _availableCatalogIds[f.tmdbId];
          final isAvailable = hit != null && hit.kind == f.kind;
          return WishlistSearchResult(
            tmdbId: f.tmdbId,
            kind: f.kind,
            title: f.title,
            year: f.year,
            posterUrl: f.posterUrl,
            availableInCatalog: isAvailable,
            catalogId: isAvailable ? hit.catalogId : null,
            alreadyInWishlist: wishlistTmdbIds.contains(f.tmdbId),
          );
        })
        .toList(growable: false);
  }

  @override
  Future<WishlistEntry> add({
    required int tmdbId,
    required WishlistItemKind kind,
  }) async {
    if (_entries.any((e) => e.tmdbId == tmdbId && e.kind == kind)) {
      throw const WishlistEntryAlreadyExistsException();
    }
    // Pick fixture metadata when available so the new card is rich ;
    // otherwise fall back to a minimal entry so the UI doesn't crash.
    final fixture = _searchFixtures.firstWhere(
      (f) => f.tmdbId == tmdbId && f.kind == kind,
      orElse: () => _SearchFixture(
        tmdbId: tmdbId,
        kind: kind,
        title: 'TMDB #$tmdbId',
        year: null,
        posterUrl: null,
      ),
    );
    final nextId =
        _entries.fold<int>(
          100,
          (max, e) => e.watcharrId > max ? e.watcharrId : max,
        ) +
        1;
    final hit = _availableCatalogIds[fixture.tmdbId];
    final created = WishlistEntry(
      watcharrId: nextId,
      tmdbId: fixture.tmdbId,
      kind: fixture.kind,
      title: fixture.title,
      year: fixture.year,
      posterUrl: fixture.posterUrl,
      status: WatchedStatus.planned,
      rating: 0,
      availableInCatalog: hit != null && hit.kind == fixture.kind,
      catalogId: (hit != null && hit.kind == fixture.kind)
          ? hit.catalogId
          : null,
    );
    _entries.add(created);
    return created;
  }

  static List<WishlistEntry> _seed() {
    return <WishlistEntry>[
      _entry(
        watcharrId: 101,
        tmdbId: 10378,
        kind: WishlistItemKind.movie,
        title: 'Big Buck Bunny',
        year: 2008,
        posterUrl:
            'https://upload.wikimedia.org/wikipedia/commons/c/c5/Big_buck_bunny_poster_big.jpg',
        status: WatchedStatus.planned,
      ),
      _entry(
        watcharrId: 102,
        tmdbId: 45745,
        kind: WishlistItemKind.movie,
        title: 'Sintel',
        year: 2010,
        posterUrl:
            'https://upload.wikimedia.org/wikipedia/commons/8/8f/Sintel_poster.jpg',
        status: WatchedStatus.planned,
      ),
      _entry(
        watcharrId: 103,
        tmdbId: 357441,
        kind: WishlistItemKind.movie,
        title: 'Cosmos Laundromat : Premier Cycle',
        year: 2015,
        posterUrl:
            'https://upload.wikimedia.org/wikipedia/commons/c/c5/CosmosLaundromatPoster.jpg',
        status: WatchedStatus.planned,
      ),
      _entry(
        watcharrId: 104,
        tmdbId: 372058,
        kind: WishlistItemKind.series,
        title: 'Caminandes',
        year: 2013,
        posterUrl:
            'https://upload.wikimedia.org/wikipedia/commons/a/aa/Blender_Foundation_-_Caminandes_-_Episode_3_-_Llamigos_-_Cover_thumbnail.png',
        status: WatchedStatus.planned,
      ),
      _entry(
        watcharrId: 105,
        tmdbId: 12345,
        kind: WishlistItemKind.movie,
        title: 'Un court métrage open-source vu il y a longtemps',
        year: 2006,
        posterUrl: null,
        status: WatchedStatus.finished,
      ),
    ];
  }

  static WishlistEntry _entry({
    required int watcharrId,
    required int tmdbId,
    required WishlistItemKind kind,
    required String title,
    required WatchedStatus status,
    int? year,
    String? posterUrl,
  }) {
    final hit = _availableCatalogIds[tmdbId];
    return WishlistEntry(
      watcharrId: watcharrId,
      tmdbId: tmdbId,
      kind: kind,
      title: title,
      year: year,
      posterUrl: posterUrl,
      status: status,
      rating: 0,
      availableInCatalog: hit != null && hit.kind == kind,
      catalogId: (hit != null && hit.kind == kind) ? hit.catalogId : null,
    );
  }
}

class _CatalogHit {
  final WishlistItemKind kind;
  final String catalogId;

  const _CatalogHit(this.kind, this.catalogId);
}

/// Lightweight fixture used by the in-memory search. A small list of
/// well-known TMDB ids with their metadata pre-filled, so the search
/// page is exercisable in dev / web mode without hitting TMDB or
/// Watcharr. The matching is a normalised `contains` on the title —
/// good enough for a fixture.
class _SearchFixture {
  final int tmdbId;
  final WishlistItemKind kind;
  final String title;
  final int? year;
  final String? posterUrl;

  const _SearchFixture({
    required this.tmdbId,
    required this.kind,
    required this.title,
    this.year,
    this.posterUrl,
  });
}

const List<_SearchFixture> _searchFixtures = [
  _SearchFixture(
    tmdbId: 10378,
    kind: WishlistItemKind.movie,
    title: 'Big Buck Bunny',
    year: 2008,
    posterUrl:
        'https://upload.wikimedia.org/wikipedia/commons/c/c5/Big_buck_bunny_poster_big.jpg',
  ),
  _SearchFixture(
    tmdbId: 45745,
    kind: WishlistItemKind.movie,
    title: 'Sintel',
    year: 2010,
    posterUrl:
        'https://upload.wikimedia.org/wikipedia/commons/8/8f/Sintel_poster.jpg',
  ),
  _SearchFixture(
    tmdbId: 9761,
    kind: WishlistItemKind.movie,
    title: 'Elephants Dream',
    year: 2006,
    posterUrl:
        'https://upload.wikimedia.org/wikipedia/commons/0/0c/ElephantsDreamPoster.jpg',
  ),
  _SearchFixture(
    tmdbId: 372058,
    kind: WishlistItemKind.series,
    title: 'Caminandes',
    year: 2013,
    posterUrl:
        'https://upload.wikimedia.org/wikipedia/commons/a/aa/Blender_Foundation_-_Caminandes_-_Episode_3_-_Llamigos_-_Cover_thumbnail.png',
  ),
  _SearchFixture(
    tmdbId: 133701,
    kind: WishlistItemKind.movie,
    title: 'Tears of Steel',
    year: 2012,
    posterUrl:
        'https://upload.wikimedia.org/wikipedia/commons/7/70/Tos-poster.png',
  ),
  _SearchFixture(
    tmdbId: 357441,
    kind: WishlistItemKind.movie,
    title: 'Cosmos Laundromat : Premier Cycle',
    year: 2015,
    posterUrl:
        'https://upload.wikimedia.org/wikipedia/commons/c/c5/CosmosLaundromatPoster.jpg',
  ),
  _SearchFixture(
    tmdbId: 581537,
    kind: WishlistItemKind.movie,
    title: 'Spring',
    year: 2019,
    posterUrl:
        'https://upload.wikimedia.org/wikipedia/commons/0/05/Spring2019PillarPosterBlender.jpg',
  ),
];
