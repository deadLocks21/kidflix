## ADDED Requirements

### Requirement: EpisodeProgress domain model

The system SHALL represent an episode watch progress as an immutable
Domain value object `EpisodeProgress` extending the sealed
`WatchProgress` class (see modified requirement below). Its fields:

- `profileId`: stable identifier of the profile (string).
- `episodeId`: stable identifier of the episode (string).
- `positionSeconds`: integer number of seconds from the start of the
  episode (`>= 0`).
- `completed`: boolean flag indicating the episode has been watched
  past the completion threshold (the same threshold used for movies).
- `updatedAt`: `DateTime` of the last save.

`EpisodeProgress` SHALL be equatable by `(profileId, episodeId)` —
two `EpisodeProgress` instances for the same profile/episode are
identical for lookup, regardless of position or timestamp.

`EpisodeProgress` SHALL NOT be considered equal to a `MovieProgress`
even when `episodeId == movieId` (different runtime types).

#### Scenario: EpisodeProgress equality by profile and episode

- **GIVEN** two `EpisodeProgress` instances with the same `profileId`
  and `episodeId` but different `positionSeconds`
- **THEN** `a == b` is true

#### Scenario: EpisodeProgress and MovieProgress with same string ids are not equal

- **GIVEN** a `MovieProgress(profileId: "p", movieId: "x", ...)` and
  an `EpisodeProgress(profileId: "p", episodeId: "x", ...)`
- **THEN** `movieProgress == episodeProgress` is false

---

## MODIFIED Requirements

### Requirement: WatchProgress domain model

The system SHALL define a `sealed class WatchProgress` in
`lib/core/domain/model/watch_progress.dart` exposing the fields
common to all watch progress entries:

- `String get profileId`
- `int get positionSeconds`
- `bool get completed`
- `DateTime get updatedAt`

The sealed hierarchy SHALL contain exactly two variants:

- `MovieProgress` — adds `final String movieId`. Equatable by
  `(profileId, movieId)`.
- `EpisodeProgress` — adds `final String episodeId`. Equatable by
  `(profileId, episodeId)`.

Any switch over `WatchProgress` SHALL be exhaustive at compile-time
without a `default` branch.

The model SHALL NOT include `deviceId` (unchanged from prior version :
multi-device identity is server-side).

The previous `WatchProgress(profileId, movieId, ...)` constructor is
removed ; sites SHALL migrate to either `MovieProgress(...)` or
`EpisodeProgress(...)` explicitly.

#### Scenario: Exhaustive switch over WatchProgress

- **GIVEN** a function that switches on `WatchProgress` runtime type
- **WHEN** a branch for `MovieProgress` or `EpisodeProgress` is omitted
- **THEN** the Dart analyzer emits a non-exhaustive switch error

#### Scenario: MovieProgress equality by profile and movie

- **GIVEN** two `MovieProgress` instances with the same `profileId`
  and `movieId`
- **THEN** `a == b` is true regardless of position or timestamp

#### Scenario: Valid zero-position progress

- **GIVEN** a `MovieProgress` (or `EpisodeProgress`) with
  `positionSeconds = 0`, `completed = false`
- **THEN** the value is valid and represents "never watched past the
  start"

---

### Requirement: WatchProgressRepository domain interface

The system SHALL define a Domain interface `WatchProgressRepository`
in `lib/core/domain/services/watch_progress.repository.dart` :

```dart
abstract interface class WatchProgressRepository {
  Future<MovieProgress?>   findForMovie({
    required String profileId,
    required String movieId,
  });

  Future<EpisodeProgress?> findForEpisode({
    required String profileId,
    required String episodeId,
  });

  Future<void> save(WatchProgress progress);

  Future<List<WatchProgress>> listForProfile(String profileId);
}
```

Contract semantics:

- `findForMovie` — returns the `MovieProgress` for `(profileId,
  movieId)`, or `null` if none. Never throws on missing data.
- `findForEpisode` — returns the `EpisodeProgress` for `(profileId,
  episodeId)`, or `null` if none.
- `save` — accepts the sealed `WatchProgress` and routes internally
  (switch on the sealed) to upsert into the right namespace. The
  sites that call `save` always know the concrete subtype at compile
  time (the player layer).
- `listForProfile` — returns every progress (movies + episodes) for
  the profile in implementation-defined order. The caller is
  responsible for sorting / filtering by kind if desired (the
  application service typically sorts by `updatedAt` desc).

The previous `findFor({profileId, movieId})` method is removed in
favor of the two typed methods. Sites that called the previous
method SHALL migrate explicitly to one or the other.

#### Scenario: findForMovie returns null when no progress

- **GIVEN** the repository has no entry for `(profileId, movieId)`
- **WHEN** `findForMovie(profileId: "p", movieId: "nemo")` is called
- **THEN** the future completes with `null`
- **AND** does NOT throw

#### Scenario: findForEpisode returns null when no progress

- **GIVEN** the repository has no entry for `(profileId, episodeId)`
- **WHEN** `findForEpisode(profileId: "p", episodeId: "s1e3")` is called
- **THEN** the future completes with `null`

#### Scenario: save routes by subtype

- **GIVEN** a `MovieProgress(profileId: "p", movieId: "nemo", ...)` and
  an `EpisodeProgress(profileId: "p", episodeId: "s1e3", ...)`
- **WHEN** `save(...)` is called on each
- **THEN** the movie progress is stored under the movie namespace
- **AND** the episode progress is stored under the episode namespace
- **AND** subsequent `findForMovie` / `findForEpisode` retrieve them
  independently

#### Scenario: listForProfile returns mixed kinds

- **GIVEN** the active profile has one `MovieProgress` and one
  `EpisodeProgress`
- **WHEN** `listForProfile(profileId)` is called
- **THEN** the returned list contains both entries
- **AND** the list type is `List<WatchProgress>` (mixed sealed)

#### Scenario: HTTP repo uses /progress/movies/ and /progress/episodes/ routes

- **GIVEN** a `DioWatchProgressRepository` consuming
  `findForMovie(profileId: "p", movieId: "nemo")` and
  `findForEpisode(profileId: "p", episodeId: "s1e3")`
- **WHEN** the calls are made
- **THEN** the first request hits
  `GET /profiles/p/progress/movies/nemo`
- **AND** the second request hits
  `GET /profiles/p/progress/episodes/s1e3`
- **AND** `listForProfile("p")` hits `GET /profiles/p/progress`

---

### Requirement: Player page orchestrates download-then-play

The `PlayerPage` widget SHALL accept a `PlayableMedia media` parameter
(the sealed defined in the `series-viewing` capability) instead of the
prior `Movie movie` parameter.

The widget internally switches on the sealed:

- `case Movie m:` → invokes `StartMoviePlaybackUseCase(m)` and saves
  progress as `MovieProgress`.
- `case Episode e:` → invokes `StartEpisodePlaybackUseCase(e)` and
  saves progress as `EpisodeProgress`. The widget MAY accept an
  optional `Series series` parameter passed by the caller (the
  series detail modal already has it loaded) to display the title bar
  as `"{series.title} — S{e.seasonNumber}E{e.episodeNumber} —
  {e.title}"`. When the series is not provided (e.g. from Continue
  Watching), the title bar shows just `"S{n}E{m} — {e.title}"` as a
  graceful fallback.

The `PlayerPage` SHALL NOT make calls to `SeriesRepository` itself —
the parent widget that already has the series in scope passes it
along ; otherwise the player works without it.

The "Lire" button on the movie detail modal continues to construct
the player with a `Movie` ; the episode card on the series detail
modal constructs it with an `Episode` ; the Continue Watching cards
construct it with the corresponding kind.

#### Scenario: PlayerPage with a Movie invokes movie playback

- **GIVEN** a `PlayerPage(media: someMovie)`
- **WHEN** the widget mounts
- **THEN** `StartMoviePlaybackUseCase` is invoked
- **AND** `StartEpisodePlaybackUseCase` is NOT invoked

#### Scenario: PlayerPage with an Episode invokes episode playback

- **GIVEN** a `PlayerPage(media: someEpisode)`
- **WHEN** the widget mounts
- **THEN** `StartEpisodePlaybackUseCase` is invoked
- **AND** `StartMoviePlaybackUseCase` is NOT invoked

#### Scenario: Title bar displays full episode reference when series is provided

- **GIVEN** a `PlayerPage(media: pinguS1E3, series: pinguSeries)`
- **WHEN** rendered
- **THEN** the title bar shows `"Pingu — S1E3 — {episodeTitle}"`

#### Scenario: Title bar shows graceful fallback without series

- **GIVEN** a `PlayerPage(media: pinguS1E3)` (series not passed)
- **WHEN** rendered
- **THEN** the title bar shows `"S1E3 — {episodeTitle}"` (no series
  prefix)
