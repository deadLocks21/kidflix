import 'package:kidflix/core/domain/model/seen_mark.dart';

/// Contract for persisting and retrieving a profile's "Déjà vu" marks on
/// movies.
///
/// All mutations are idempotent server-side per `SEEN_FEATURE.md`:
/// marking an already-seen movie is a `204` no-op, unmarking an unknown
/// pair is also a `204` no-op (the spec forbids `404` on `DELETE`,
/// mirroring the favorites contract).
///
/// [markMovies] is the bulk-entry primitive backing the "saisie en
/// masse" screen: a single round-trip for the whole selection rather
/// than N unitary `PUT`s.
///
/// Implementations live in `lib/infrastructure/seen/`.
abstract interface class SeenRepository {
  /// Returns every "déjà vu" mark recorded for [profileId] in an
  /// implementation-defined order. Empty list when none exists.
  Future<List<SeenMark>> listForProfile(String profileId);

  /// Marks a movie as already seen. Idempotent.
  Future<void> markMovie({required String profileId, required String movieId});

  /// Clears the "déjà vu" mark on a movie. Idempotent.
  Future<void> unmarkMovie({
    required String profileId,
    required String movieId,
  });

  /// Marks every id in [movieIds] as already seen in a single
  /// round-trip. Idempotent per id ; an empty list is a no-op.
  Future<void> markMovies({
    required String profileId,
    required List<String> movieIds,
  });
}
