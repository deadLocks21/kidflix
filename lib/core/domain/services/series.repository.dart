import 'package:kidflix/core/domain/model/media.dart';

/// Contract for fetching the full hierarchical structure of a single
/// [Series].
///
/// Returns a [Series] populated with its non-deleted seasons (sorted by
/// `seasonNumber` ascending) and each season's non-deleted episodes
/// (sorted by `episodeNumber` ascending). Soft-deleted seasons or
/// episodes are absent from the returned tree.
///
/// Caching is **not** the repository's responsibility — implementations
/// always issue a fresh fetch. Callers that need to memoize a series
/// should do so via a Riverpod provider (out of scope for the MVP, see
/// `add-series-viewing/design.md` D-3).
///
/// Implementations live in `lib/infrastructure/series/`.
abstract interface class SeriesRepository {
  /// Returns the [Series] identified by [seriesId] with its full
  /// `seasons` / `episodes` hierarchy.
  ///
  /// Throws if the series does not exist or is out of the active
  /// profile's age range. The exact exception type is implementation-
  /// specific (`DioException` in HTTP mode, a generic `StateError` /
  /// `Exception` in in-memory mode) — callers SHALL NOT match on a
  /// Domain exception. The future never completes with `null`.
  Future<Series> findById(String seriesId);
}
