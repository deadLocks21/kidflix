import 'package:kidflix/core/domain/model/wishlist_entry.dart';
import 'package:kidflix/core/domain/services/wishlist.repository.dart';

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
    // Pretend "Astérix & Obélix : L'Empire du Milieu" (tmdb 631842) is
    // already in the kdrive catalog — matches the catalog seed in
    // `InMemoryCatalogRepository`.
    631842: _CatalogHit(WishlistItemKind.movie, 'asterix-empire-du-milieu'),
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

  static List<WishlistEntry> _seed() {
    return <WishlistEntry>[
      _entry(
        watcharrId: 101,
        tmdbId: 631842,
        kind: WishlistItemKind.movie,
        title: "Astérix & Obélix : L'Empire du Milieu",
        year: 2023,
        posterUrl:
            'https://image.tmdb.org/t/p/w500/vchpiQLvXa4uyZhqdEwttrsFOOC.jpg',
        status: WatchedStatus.planned,
      ),
      _entry(
        watcharrId: 102,
        tmdbId: 22,
        kind: WishlistItemKind.movie,
        title: 'Pirates des Caraïbes : La Malédiction du Black Pearl',
        year: 2003,
        posterUrl:
            'https://image.tmdb.org/t/p/w500/k6F5MQzN3WFolXcS9bdW1ZUaPxq.jpg',
        status: WatchedStatus.planned,
      ),
      _entry(
        watcharrId: 103,
        tmdbId: 11216,
        kind: WishlistItemKind.movie,
        title: 'Cinema Paradiso',
        year: 1988,
        posterUrl:
            'https://image.tmdb.org/t/p/w500/wIxNVQqlbiZcCWjk2DlH50sxieO.jpg',
        status: WatchedStatus.planned,
      ),
      _entry(
        watcharrId: 104,
        tmdbId: 1399,
        kind: WishlistItemKind.series,
        title: 'Game of Thrones',
        year: 2011,
        posterUrl:
            'https://image.tmdb.org/t/p/w500/u3bZgnGQ9T01sWNhyveQz0wH0Hl.jpg',
        status: WatchedStatus.planned,
      ),
      _entry(
        watcharrId: 105,
        tmdbId: 12345,
        kind: WishlistItemKind.movie,
        title: 'Un vieux classique vu il y a longtemps',
        year: 1995,
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
