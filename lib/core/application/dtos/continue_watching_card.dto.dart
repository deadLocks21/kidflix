import 'package:kidflix/core/application/dtos/catalog_item.dto.dart';

/// Catalog row entry for the "Continuer à regarder" row.
///
/// Wraps an [inner] `MovieDto` or `SeriesDto` and carries the resume
/// [progress] (a fraction in `[0, 1]`) so the home row can overlay a
/// thin progress bar on the poster. The wrapper is exclusive to that
/// row — every other row keeps emitting bare `MovieDto` / `SeriesDto`.
///
/// [dismissTarget] points to the underlying [WatchProgress] entry that
/// would be dismissed if the user long-presses the card. For a movie
/// entry, that is the movie itself ; for a series entry, that is the
/// **whole** series (the row dedups by series, but the user may have
/// progress on several episodes — dismissing one only would let the
/// next-most-recent episode resurface immediately, so we dismiss every
/// episode of the series in one go).
///
/// `CatalogItemDto` getters delegate to [inner] so the existing search /
/// modal navigation paths keep working when the row's tap callback
/// receives the unwrapped item.
class ContinueWatchingCardDto implements CatalogItemDto {
  final CatalogItemDto inner;
  final double progress;
  final ContinueWatchingDismissTarget dismissTarget;

  ContinueWatchingCardDto({
    required this.inner,
    required this.dismissTarget,
    required double progress,
  }) : progress = progress.isNaN ? 0.0 : progress.clamp(0.0, 1.0);

  @override
  String get id => inner.id;
  @override
  String get title => inner.title;
  @override
  int? get year => inner.year;
  @override
  String? get posterUrl => inner.posterUrl;
  @override
  String get ageCategory => inner.ageCategory;
}

/// Sealed pointer to the [WatchProgress] entry behind a Continue Watching
/// card. Carries only what the dismiss endpoints need (the URL path
/// segment kind + id).
sealed class ContinueWatchingDismissTarget {
  const ContinueWatchingDismissTarget();
}

class MovieDismissTarget extends ContinueWatchingDismissTarget {
  final String movieId;
  const MovieDismissTarget(this.movieId);
}

/// Dismissing a series-level Continue Watching card sweeps **every**
/// episode of the series — the row dedups by series, so dismissing a
/// single episode would let the next-most-recent episode of the same
/// series reappear on the next refresh.
class SeriesDismissTarget extends ContinueWatchingDismissTarget {
  final String seriesId;

  /// Universe of episode ids belonging to the series, collected at
  /// resolve time. The dismiss use case filters this against the
  /// actual stored progresses so unrelated dismiss calls don't fire.
  final List<String> episodeIds;

  const SeriesDismissTarget({
    required this.seriesId,
    required this.episodeIds,
  });
}
