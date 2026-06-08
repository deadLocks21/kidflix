import 'package:kidflix/core/domain/model/seen_mark.dart';
import 'package:kidflix/core/domain/services/seen.repository.dart';

/// RAM-only [SeenRepository] used in dev / web / tests.
///
/// Entries are lost at app restart — acceptable for the in-memory base
/// URL. The HTTP replacement preserves the same contract, so the bulk
/// entry screen and the per-film toggle are fully exercisable without a
/// backend.
///
/// Keyed on `(profileId, movieId)`. [markMovie] is idempotent: re-marking
/// keeps the original `markedAt` (matches the server's `PUT` no-op
/// semantics — `marked_at` is not refreshed on a no-op).
class InMemorySeenRepository implements SeenRepository {
  final Map<String, SeenMark> _marks = {};

  String _key(String profileId, String movieId) => '$profileId|$movieId';

  @override
  Future<List<SeenMark>> listForProfile(String profileId) async {
    return _marks.values
        .where((m) => m.profileId == profileId)
        .toList(growable: false);
  }

  @override
  Future<void> markMovie({
    required String profileId,
    required String movieId,
  }) async {
    _marks.putIfAbsent(
      _key(profileId, movieId),
      () => SeenMark(
        profileId: profileId,
        movieId: movieId,
        markedAt: DateTime.now().toUtc(),
      ),
    );
  }

  @override
  Future<void> unmarkMovie({
    required String profileId,
    required String movieId,
  }) async {
    _marks.remove(_key(profileId, movieId));
  }

  @override
  Future<void> markMovies({
    required String profileId,
    required List<String> movieIds,
  }) async {
    for (final id in movieIds) {
      await markMovie(profileId: profileId, movieId: id);
    }
  }
}
