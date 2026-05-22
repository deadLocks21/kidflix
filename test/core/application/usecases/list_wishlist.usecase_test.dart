import 'package:flutter_test/flutter_test.dart';
import 'package:kidflix/core/application/dtos/wishlist_entry.dto.dart';
import 'package:kidflix/core/application/usecases/list_wishlist.usecase.dart';
import 'package:kidflix/core/domain/model/watch_progress.dart';
import 'package:kidflix/core/domain/model/wishlist_entry.dart';
import 'package:kidflix/core/domain/model/wishlist_search_result.dart';
import 'package:kidflix/core/domain/services/watch_progress.repository.dart';
import 'package:kidflix/core/domain/services/wishlist.repository.dart';

class _WishlistStub implements WishlistRepository {
  final List<WishlistEntry> _seed;
  _WishlistStub(this._seed);

  @override
  Future<List<WishlistEntry>> list() async => List.of(_seed);

  @override
  Future<WishlistEntry> updateStatus({
    required int watcharrId,
    required WatchedStatus status,
  }) => throw UnimplementedError();

  @override
  Future<void> remove(int watcharrId) => throw UnimplementedError();

  @override
  Future<List<WishlistSearchResult>> search(String query) =>
      throw UnimplementedError();

  @override
  Future<WishlistEntry> add({
    required int tmdbId,
    required WishlistItemKind kind,
  }) => throw UnimplementedError();
}

class _ProgressStub implements WatchProgressRepository {
  /// `profileId → list of progress`. Returned verbatim by `listForProfile`.
  final Map<String, List<WatchProgress>> _progressByProfile;

  _ProgressStub(this._progressByProfile);

  @override
  Future<List<WatchProgress>> listForProfile(String profileId) async =>
      _progressByProfile[profileId] ?? const [];

  @override
  Future<MovieProgress?> findForMovie({
    required String profileId,
    required String movieId,
  }) => throw UnimplementedError();

  @override
  Future<EpisodeProgress?> findForEpisode({
    required String profileId,
    required String episodeId,
  }) => throw UnimplementedError();

  @override
  Future<void> save(WatchProgress progress) => throw UnimplementedError();

  @override
  Future<void> dismissMovie({
    required String profileId,
    required String movieId,
  }) => throw UnimplementedError();

  @override
  Future<void> unDismissMovie({
    required String profileId,
    required String movieId,
  }) => throw UnimplementedError();

  @override
  Future<void> dismissEpisode({
    required String profileId,
    required String episodeId,
  }) => throw UnimplementedError();

  @override
  Future<void> unDismissEpisode({
    required String profileId,
    required String episodeId,
  }) => throw UnimplementedError();
}

WishlistEntry _entry({
  required int watcharrId,
  required String title,
  WishlistItemKind kind = WishlistItemKind.movie,
  WatchedStatus status = WatchedStatus.planned,
  bool available = false,
  String? catalogId,
}) => WishlistEntry(
  watcharrId: watcharrId,
  tmdbId: 1000 + watcharrId,
  kind: kind,
  title: title,
  status: status,
  rating: 0,
  availableInCatalog: available,
  catalogId: available ? (catalogId ?? 'catalog-$watcharrId') : null,
);

MovieProgress _completed(String profileId, String movieId) => MovieProgress(
  profileId: profileId,
  movieId: movieId,
  positionSeconds: 1000,
  completed: true,
  updatedAt: DateTime.utc(2026, 5, 1),
);

MovieProgress _inProgress(String profileId, String movieId) => MovieProgress(
  profileId: profileId,
  movieId: movieId,
  positionSeconds: 200,
  completed: false,
  updatedAt: DateTime.utc(2026, 5, 1),
);

ListWishlistUseCase _buildUseCase({
  required List<WishlistEntry> wishlist,
  Map<String, List<WatchProgress>> progress = const {},
}) => ListWishlistUseCase(
  wishlistRepo: _WishlistStub(wishlist),
  progressRepo: _ProgressStub(progress),
);

void main() {
  group('ListWishlistUseCase.execute — filter on PLANNED', () {
    test('returns an empty list when the repository is empty', () async {
      final usecase = _buildUseCase(wishlist: const []);
      final result = await usecase.execute(profileIds: const []);
      expect(result, isEmpty);
    });

    test('drops every non-PLANNED status', () async {
      final entries = [
        _entry(watcharrId: 1, title: 'Keep'),
        _entry(
          watcharrId: 2,
          title: 'Watching — dropped',
          status: WatchedStatus.watching,
        ),
        _entry(
          watcharrId: 3,
          title: 'Hold — dropped',
          status: WatchedStatus.hold,
        ),
        _entry(
          watcharrId: 4,
          title: 'Finished — dropped',
          status: WatchedStatus.finished,
        ),
        _entry(
          watcharrId: 5,
          title: 'Dropped — dropped',
          status: WatchedStatus.dropped,
        ),
      ];
      final result = await _buildUseCase(
        wishlist: entries,
      ).execute(profileIds: const []);
      expect(result.map((e) => e.title), ['Keep']);
    });

    test('sorts survivors alphabetically (case-insensitive)', () async {
      final entries = [
        _entry(watcharrId: 1, title: 'Zorro'),
        _entry(watcharrId: 2, title: 'abeille'),
        _entry(watcharrId: 3, title: 'Manchot'),
      ];
      final result = await _buildUseCase(
        wishlist: entries,
      ).execute(profileIds: const []);
      expect(result.map((e) => e.title), ['abeille', 'Manchot', 'Zorro']);
    });
  });

  group('ListWishlistUseCase.execute — categorisation', () {
    test('flags entries not in the catalog as toAcquire', () async {
      final result = await _buildUseCase(
        wishlist: [_entry(watcharrId: 1, title: 'Indispo')],
      ).execute(profileIds: const ['p1']);
      expect(result.single.category, WishlistCategory.toAcquire);
    });

    test(
      'flags in-catalog movies as toWatch when no profile watched it',
      () async {
        final result = await _buildUseCase(
          wishlist: [
            _entry(
              watcharrId: 1,
              title: 'Astérix',
              available: true,
              catalogId: 'asterix',
            ),
          ],
          progress: {
            'p1': [_inProgress('p1', 'asterix')], // started but not completed
          },
        ).execute(profileIds: const ['p1']);
        expect(result.single.category, WishlistCategory.toWatch);
      },
    );

    test('flags in-catalog movies as watched when ANY profile of the foyer '
        'has completed them', () async {
      final result = await _buildUseCase(
        wishlist: [
          _entry(
            watcharrId: 1,
            title: 'Astérix',
            available: true,
            catalogId: 'asterix',
          ),
        ],
        progress: {
          'p_parent': const [], // parent never watched
          'p_kid': [_completed('p_kid', 'asterix')], // kid completed
        },
      ).execute(profileIds: const ['p_parent', 'p_kid']);
      expect(result.single.category, WishlistCategory.watched);
    });

    test(
      'flags in-catalog series as toWatch even with episode progress',
      () async {
        // Series category is never `watched` in v1 — episode-level
        // progress is granular and the wishlist tracks the series as a
        // single unit.
        final result = await _buildUseCase(
          wishlist: [
            _entry(
              watcharrId: 1,
              title: 'Pingu',
              kind: WishlistItemKind.series,
              available: true,
              catalogId: 'pingu',
            ),
          ],
          progress: {
            'p_kid': [
              EpisodeProgress(
                profileId: 'p_kid',
                episodeId: 'pingu-s1e1',
                positionSeconds: 300,
                completed: true,
                updatedAt: DateTime.utc(2026, 5, 1),
              ),
            ],
          },
        ).execute(profileIds: const ['p_kid']);
        expect(result.single.category, WishlistCategory.toWatch);
      },
    );

    test('ignores movie progress for unrelated catalogIds', () async {
      final result = await _buildUseCase(
        wishlist: [
          _entry(
            watcharrId: 1,
            title: 'Astérix',
            available: true,
            catalogId: 'asterix',
          ),
        ],
        progress: {
          'p1': [_completed('p1', 'some-other-movie')],
        },
      ).execute(profileIds: const ['p1']);
      expect(result.single.category, WishlistCategory.toWatch);
    });

    test('mixed bucket distribution', () async {
      final result = await _buildUseCase(
        wishlist: [
          _entry(watcharrId: 1, title: 'Pirates'),
          _entry(
            watcharrId: 2,
            title: 'Astérix',
            available: true,
            catalogId: 'asterix',
          ),
          _entry(
            watcharrId: 3,
            title: 'Bambi',
            available: true,
            catalogId: 'bambi',
          ),
          _entry(
            watcharrId: 4,
            title: 'Pingu',
            kind: WishlistItemKind.series,
            available: true,
            catalogId: 'pingu',
          ),
        ],
        progress: {
          'p1': [_completed('p1', 'bambi')],
        },
      ).execute(profileIds: const ['p1']);
      final byTitle = {for (final e in result) e.title: e.category};
      expect(byTitle, {
        'Astérix': WishlistCategory.toWatch,
        'Bambi': WishlistCategory.watched,
        'Pingu': WishlistCategory.toWatch,
        'Pirates': WishlistCategory.toAcquire,
      });
    });
  });
}
