# series-viewing Specification

## Purpose
TBD - created by archiving change add-series-viewing. Update Purpose after archive.
## Requirements
### Requirement: Series, Season, Episode domain model

The system SHALL represent a TV series and its hierarchical structure
as immutable Domain entities living in
`lib/core/domain/model/media.dart` (alongside the `Movie` entity, see
`catalog` capability).

`Series` SHALL extend the sealed class `CatalogItem` (defined in the
`catalog` capability) with the following series-specific fields:

- `seasonsCount`: integer ≥ 0, total non-deleted seasons known to the
  backend (computed server-side and projected to the client; not the
  length of the local `seasons` field).
- `episodesCount`: integer ≥ 0, total non-deleted episodes across
  all seasons (also server-computed).
- `seasons`: `List<Season>` — empty when the `Series` instance comes
  from `/catalog`, populated when it comes from
  `SeriesRepository.findById`. The same `Series` identifier may be
  represented by an empty-`seasons` snapshot and a populated-`seasons`
  snapshot at different points in the application lifecycle.

`Series` SHALL be equatable by `id`. It SHALL NOT implement
`PlayableMedia` — a series is not directly playable (only its
episodes are).

`Season` SHALL be a non-sealed Domain class with the following fields:

- `seasonNumber`: integer ≥ 0. The value `0` denotes the TMM/Plex
  convention "Specials".
- `name`: nullable string. Non-null only for special-purpose seasons
  (typically "Specials" for season 0 when the source NFO names it).
- `posterUrl`: nullable string.
- `synopsis`: nullable string.
- `episodes`: `List<Episode>` — sorted by `episodeNumber` ascending.

`Season` SHALL NOT have a stable identifier of its own beyond its
`(parent series id, seasonNumber)` composite — it is a value object
owned by its `Series`.

`Episode` SHALL extend the sealed class `PlayableMedia` (defined in
this capability) with the following fields:

- `id`: stable identifier (string).
- `seriesId`: identifier of the parent series.
- `seasonNumber`: integer ≥ 0.
- `episodeNumber`: integer ≥ 1.
- `title`: non-empty string.
- `originalTitle`: nullable string.
- `synopsis`: nullable string.
- `duration`: `Duration`.
- `thumbUrl`: nullable string.
- `airedAt`: nullable `DateTime` (date-only, parsed from a `YYYY-MM-DD`
  wire field; the time component is `00:00:00 UTC` by convention).
- `ageCategory`: `AgeCategory` — denormalized from the parent series'
  age category for convenience of the player layer (which receives a
  raw `PlayableMedia`).
- `addedAt`: `DateTime`.

`Episode` SHALL be equatable by `id`.

#### Scenario: Series carries seasonsCount and episodesCount

- **GIVEN** a `Series` with `seasonsCount = 6` and `episodesCount = 105`
- **THEN** these values reflect the backend's count of non-deleted
  seasons and episodes
- **AND** they MAY differ from `seasons.length` when the local
  `seasons` field is empty (catalog projection) or partially loaded

#### Scenario: Series is a CatalogItem but not a PlayableMedia

- **GIVEN** a `Series` instance
- **THEN** it is `is CatalogItem` true
- **AND** it is `is PlayableMedia` false

#### Scenario: Episode is a PlayableMedia but not a CatalogItem

- **GIVEN** an `Episode` instance
- **THEN** it is `is PlayableMedia` true
- **AND** it is `is CatalogItem` false

#### Scenario: Episode equality by id alone

- **GIVEN** two `Episode` instances with the same `id` but different
  `positionSeconds` would not apply (Episode has no position field) —
  different `seriesId` would be a contract bug
- **WHEN** comparing equality on identical `id`
- **THEN** they are considered equal

#### Scenario: Season 0 represents Specials

- **GIVEN** a `Season` with `seasonNumber = 0`
- **THEN** it represents the "Specials" category sourced from the
  TMM convention `Season 0/` or `Specials/` directory
- **AND** the UI displays it last regardless of numeric ordering
  (see UI requirement below)

---

### Requirement: PlayableMedia sealed hierarchy

The system SHALL define a `sealed class PlayableMedia` in
`lib/core/domain/model/media.dart` with the following abstract getters:

- `String get id`
- `Duration get duration`
- `AgeCategory get ageCategory`

The sealed hierarchy SHALL contain exactly two variants:

- `Movie` (defined in the `catalog` capability) — `implements
  PlayableMedia` (it already extends `CatalogItem`, so cannot
  `extends PlayableMedia` directly).
- `Episode` (defined in this capability) — `extends PlayableMedia`.

Any switch over `PlayableMedia` SHALL be exhaustive at compile-time
without a `default` branch.

#### Scenario: Exhaustive switch over PlayableMedia

- **GIVEN** a function `download(PlayableMedia m)` that switches on
  the runtime type
- **WHEN** the function omits a branch for `Movie` or `Episode`
- **THEN** the Dart analyzer emits a non-exhaustive switch error

#### Scenario: Movie satisfies the PlayableMedia interface

- **GIVEN** a `Movie` with `id == "nemo"` and `duration == 100min`
- **WHEN** treated as `PlayableMedia`
- **THEN** `playable.id == "nemo"` and `playable.duration == 100min`

---

### Requirement: SeriesRepository Domain interface

The system SHALL define a Domain interface `SeriesRepository` in
`lib/core/domain/services/series.repository.dart`:

```dart
abstract interface class SeriesRepository {
  Future<Series> findById(String seriesId);
}
```

`findById` SHALL return a fully-loaded `Series` instance with non-empty
`seasons` (each `Season` having its `episodes` populated). The
returned series SHALL have its seasons sorted by `seasonNumber`
ascending and each season's episodes sorted by `episodeNumber`
ascending. Soft-deleted seasons and episodes SHALL be absent from the
returned tree.

The repository SHALL throw a Domain or HTTP exception when the series
does not exist or is out of the active profile's age range. The shape
of the thrown exception is implementation-specific (`DioException` for
HTTP, a custom `NotFoundException` or similar for in-memory) — the
contract is that the future does not complete with `null`.

The repository SHALL NOT cache its responses internally — caching, if
needed, is the caller's responsibility (e.g. via a Riverpod provider).

#### Scenario: findById returns full hierarchy

- **GIVEN** a series Pingu in the backing store with 2 seasons and 5
  episodes each, plus 2 specials
- **WHEN** `findById("pingu")` is called
- **THEN** the returned `Series` has `seasons.length == 3` (Specials +
  Season 1 + Season 2)
- **AND** seasons are ordered `[0, 1, 2]` by `seasonNumber`
- **AND** each season's episodes are ordered by `episodeNumber`

#### Scenario: findById on unknown series throws

- **GIVEN** no series exists with id `"unknown"`
- **WHEN** `findById("unknown")` is called
- **THEN** the future throws (the exception type is implementation-specific)
- **AND** the future does NOT complete with `null`

---

### Requirement: In-memory SeriesRepository seeds at least one full series

The in-memory implementation `InMemorySeriesRepository` SHALL seed at
least one fictional series — by convention "Pingu" — with the
following minima:

- ≥ 2 seasons including a Specials season (`seasonNumber = 0`).
- ≥ 5 episodes in each non-Specials season.
- ≥ 1 episode in the Specials season.
- All episodes carry a non-null `thumbUrl`, a non-null `addedAt`, a
  non-null `duration`, and a unique `id` across the whole series.

The seeded `Series.ageCategory` SHALL be `enfant` so it appears in the
default in-memory "enfant" profile.

The repository SHALL apply no age filter (consistent with the
in-memory `CatalogRepository`'s posture: profile-scoped age filtering
is validated by the backend, not by the in-memory repos).

#### Scenario: Pingu seed exposed by findById

- **GIVEN** the default in-memory seed
- **WHEN** `findById("pingu")` is called
- **THEN** a `Series` with title `"Pingu"`, `ageCategory == enfant`,
  ≥ 3 `seasons` (Specials + 2 normal) is returned

---

### Requirement: HTTP SeriesRepository (DioSeriesRepository)

The system SHALL provide an HTTP implementation `DioSeriesRepository
implements SeriesRepository` in
`lib/infrastructure/series/dio.series.repository.dart` that calls the
backend `/series/{id}` endpoint documented in `API.md` § Détail d'une
série.

The class SHALL accept a `Dio` instance via its constructor, with the
`AuthInterceptor` already wired (consistent with all other Dio
repositories). It SHALL NOT add `Authorization`, `X-Device-Id`, or
`X-Profile-Id` headers explicitly.

`findById(seriesId)` SHALL:

1. Issue `GET /series/<seriesId>`.
2. On HTTP 200, parse the body via
   `RemoteSeriesDetailDto.fromJson(...).toDomain()`.
3. On `DioException`, rethrow without metier mapping. The 403
   `forbidden_age_category` and 404 `not_found` documented in `API.md`
   surface as generic `DioException` instances ; the UI consumes them
   through Riverpod async error handling.

The repository SHALL NOT log raw response bodies or any header value.

#### Scenario: findById sends GET /series/{id} and parses detail

- **GIVEN** the backend responds 200 with a Pingu detail payload
  matching `API.md` § Détail d'une série
- **WHEN** `findById("pingu")` is called
- **THEN** the request method is `GET` on path `/series/pingu`
- **AND** the future completes with a `Series` whose `id == "pingu"`
- **AND** every season has its episodes populated, sorted by
  `episodeNumber`

#### Scenario: rethrows on 403 forbidden_age_category

- **GIVEN** the backend responds 403 with `{"error": {"code": "forbidden_age_category"}}`
- **WHEN** `findById(...)` is called
- **THEN** the future throws `DioException` with `statusCode == 403`
- **AND** does NOT throw a Domain exception

#### Scenario: rethrows on 404 not_found

- **GIVEN** the backend responds 404 with `{"error": {"code": "not_found"}}`
- **WHEN** `findById(...)` is called
- **THEN** the future throws `DioException` with `statusCode == 404`

#### Scenario: AuthInterceptor injects all three headers transparently

- **GIVEN** a session is established and a profile is selected
- **WHEN** `findById(...)` is called
- **THEN** the outbound request carries `Authorization: Bearer <jwt>`,
  `X-Device-Id: <device.id>`, and `X-Profile-Id: <profile.id>`
- **AND** the repository code does not reference these headers explicitly

---

### Requirement: SeriesRepository implementation selection via API_BASE_URL

The system SHALL select between in-memory and HTTP implementations of
`SeriesRepository` based on the compile-time constant
`String.fromEnvironment('API_BASE_URL')`, mirroring the selection
logic of `CatalogRepository`, `AuthRepository`,
`ProfileManagementRepository`, `DownloadRepository`, and
`WatchProgressRepository`.

The selection SHALL live in
`lib/infrastructure/providers/series.repository_provider.dart` and
SHALL behave as follows:

```dart
const baseUrl = String.fromEnvironment('API_BASE_URL');
if (baseUrl.isEmpty) {
  return InMemorySeriesRepository();
}
return DioSeriesRepository(ref.watch(dioProvider));
```

The provider SHALL be `@Riverpod(keepAlive: true)`.

#### Scenario: Default build returns InMemorySeriesRepository

- **GIVEN** the app is built without `--dart-define=API_BASE_URL`
- **WHEN** any consumer reads `seriesRepositoryProvider`
- **THEN** the returned instance is of runtime type
  `InMemorySeriesRepository`

#### Scenario: Build with API_BASE_URL returns DioSeriesRepository

- **GIVEN** the app is built with `--dart-define=API_BASE_URL=http://localhost:8080`
- **WHEN** any consumer reads `seriesRepositoryProvider`
- **THEN** the returned instance is of runtime type
  `DioSeriesRepository`

---

### Requirement: RemoteSeriesCatalogDto and RemoteSeriesDetailDto wire DTOs

The system SHALL define two wire-format DTOs in
`lib/core/application/dtos/remote_series.dto.dart`:

`RemoteSeriesCatalogDto` mediates the `kind: "series"` wire shape
returned by `GET /catalog` and `GET /catalog/search`. Its wire schema:

| Wire field | Wire type | Domain mapping |
|---|---|---|
| `id` | `String` | direct |
| `title` | `String` | direct |
| `original_title` | `String?` | direct |
| `year` | `int?` | direct |
| `seasons_count` | `int` | direct |
| `episodes_count` | `int` | direct |
| `synopsis` | `String` | direct |
| `tagline` | `String?` | direct |
| `poster_url` | `String?` | direct |
| `backdrop_url` | `String?` | direct |
| `age_category` | `String` | `ageCategoryFromWire(...)` |
| `genres` | `List<String>` | direct |
| `saga_id` | `String?` | direct |
| `saga_label` | `String?` | direct |
| `director` | `List<String>` | direct |
| `cast` | `List<Map>` | each via `RemoteCastMemberDto.fromJson` |
| `added_at` | `String` (ISO 8601) | `DateTime.parse(...)` |

`toDomain()` produces a `Series` with `seasons: const []`.

`RemoteSeriesDetailDto` mediates the wire shape returned by
`GET /series/{id}`. It carries every field of
`RemoteSeriesCatalogDto` (without `seasons_count` /
`episodes_count` — those are absent from the detail payload) plus:

| Wire field | Wire type | Domain mapping |
|---|---|---|
| `seasons` | `List<Map>` | each via `RemoteSeasonDto.fromJson` |

`toDomain()` produces a `Series` with `seasons` non-empty. The
`seasonsCount` and `episodesCount` fields are recomputed locally from
`seasons.length` and the sum of `season.episodes.length`, since the
detail payload does not carry the server-computed counts.

`RemoteSeasonDto` wire schema:

| Wire field | Wire type | Domain mapping |
|---|---|---|
| `season_number` | `int` | direct |
| `name` | `String?` | direct |
| `poster_url` | `String?` | direct |
| `synopsis` | `String?` | direct |
| `episodes` | `List<Map>` | each via `RemoteEpisodeDto.fromJson` |

`RemoteEpisodeDto` wire schema:

| Wire field | Wire type | Domain mapping |
|---|---|---|
| `id` | `String` | direct |
| `episode_number` | `int` | direct |
| `title` | `String` | direct |
| `original_title` | `String?` | direct |
| `synopsis` | `String?` | direct |
| `duration_seconds` | `int` | `Duration(seconds: ...)` in toDomain |
| `thumb_url` | `String?` | direct |
| `aired_at` | `String?` (`YYYY-MM-DD`) | `DateTime.parse(...)?` in toDomain |
| `added_at` | `String` (ISO 8601) | `DateTime.parse(...)` |

The episode's `seriesId`, `seasonNumber`, and `ageCategory` SHALL be
injected by the `RemoteEpisodeDto.toDomain` method via parameters,
since the wire payload does not repeat them on each episode (they
are inherited from the enclosing series and season).

`RemoteSeriesCatalogDto.fromJson` and `RemoteSeriesDetailDto.fromJson`
SHALL throw `FormatException` on missing required fields (the
"required" set follows the `not null?` markers in the table above).

#### Scenario: Parses a catalog series

- **GIVEN** a wire payload `{"kind": "series", "id": "pingu",
  "title": "Pingu", "seasons_count": 6, "episodes_count": 105, ...}`
- **WHEN** `RemoteSeriesCatalogDto.fromJson(payload).toDomain()`
- **THEN** the returned `Series` has `seasonsCount == 6`,
  `episodesCount == 105`, `seasons == []`

#### Scenario: Parses a series detail with Specials

- **GIVEN** a wire payload from `GET /series/pingu` containing a
  season with `season_number: 0` and 2 episodes, then `season_number:
  1` with 5 episodes
- **WHEN** `RemoteSeriesDetailDto.fromJson(payload).toDomain()`
- **THEN** the returned `Series` has `seasons.length == 2`
- **AND** `seasons[0].seasonNumber == 0` (Specials, in payload order)
- **AND** every episode in `seasons[0]` has `seriesId == "pingu"`,
  `seasonNumber == 0`, `ageCategory == series.ageCategory`

#### Scenario: Episode without aired_at parses as null

- **GIVEN** a wire payload with `aired_at: null` on an episode
- **WHEN** parsed
- **THEN** the resulting `Episode.airedAt == null`

---

### Requirement: ResolveContinueWatchingUseCase computes the Continue Watching row

The system SHALL define an Application-layer usecase
`ResolveContinueWatchingUseCase` in
`lib/core/application/usecases/resolve_continue_watching.usecase.dart`
exposing:

```dart
Future<List<ContinueWatchingItemDto>> execute(ProfileDto profile);
```

The usecase SHALL:

1. Fetch all watch progresses for the profile via
   `WatchProgressRepository.listForProfile(profile.id)`.
2. Sort them by `updatedAt` descending.
3. For each progress entry:
   - **MovieProgress** → resolve the `Movie` from the catalog (via
     `CatalogRepository.listCatalog` already in scope, or a passed-in
     resolver). Emit a `MovieContinueDto(movie, resumeSeconds:
     progress.positionSeconds, completed: progress.completed)`.
   - **EpisodeProgress** → call
     `SeriesRepository.findById(parentSeriesId)` (the parent series
     id is recoverable: it comes from the episode's catalog cache in
     practice — design.md leaves this resolver injected) and apply
     the next-episode rule:
     - if `progress.completed == false` → emit
       `EpisodeContinueDto(series, episode, resumeSeconds:
       progress.positionSeconds, kind: inProgress)`.
     - if `progress.completed == true` and a next episode exists in
       the series (next episode in the same season, or first episode
       of the next season, ignoring Specials season 0) → emit
       `EpisodeContinueDto(series, nextEp, resumeSeconds: 0, kind:
       nextAfterCompleted)`.
     - if `progress.completed == true` and no next episode exists
       (the user finished the series) → emit `EpisodeContinueDto(series,
       firstEpisode, resumeSeconds: 0, kind: restart)` where
       `firstEpisode` is `season1.episodes.first` (Specials are
       excluded from this rotation).
4. Deduplicate by `seriesId`: when multiple `EpisodeContinueDto` items
   resolve to the same series, keep only the one whose underlying
   progress has the most recent `updatedAt`. Movies are not
   deduplicated.
5. Return the list in the resulting order (already sorted by step 2).

If `SeriesRepository.findById` throws for a given series id, the
usecase SHALL log the error and **omit that item** from the result.
It SHALL NOT propagate the exception. Other entries in the list are
unaffected.

The usecase SHALL expose a public helper
`resolveContinueWatchingForSeries(Series, EpisodeProgress?) ->
ContinueWatchingState` that the UI layer reuses to compute the
"Lire" button label on the series detail modal (see UI requirement).
The state value is the same enum used in step 3.

#### Scenario: Profile with no progress yields empty list

- **GIVEN** `listForProfile(profile.id)` returns an empty list
- **WHEN** `execute(profile)` is called
- **THEN** the future completes with an empty list

#### Scenario: Single in-progress movie

- **GIVEN** one `MovieProgress` for `nemo` at 1845 seconds, not completed
- **WHEN** `execute(profile)` is called
- **THEN** the result has length 1
- **AND** it is a `MovieContinueDto` with `resumeSeconds == 1845`

#### Scenario: In-progress episode

- **GIVEN** one `EpisodeProgress` for episode `s1e3` of Pingu at 240
  seconds, completed = false
- **WHEN** `execute(profile)` is called
- **THEN** the result has length 1
- **AND** it is an `EpisodeContinueDto(series: pingu, episode: s1e3,
  resumeSeconds: 240, kind: inProgress)`

#### Scenario: Episode completed mid-season → next episode same season

- **GIVEN** one `EpisodeProgress` for episode `s1e3` of Pingu, completed
- **AND** the series has 5 episodes in season 1
- **WHEN** `execute(profile)` is called
- **THEN** the result has length 1
- **AND** the dto's episode is `s1e4`, `resumeSeconds == 0`, kind ==
  nextAfterCompleted

#### Scenario: Episode completed at end of season → first episode next season

- **GIVEN** one `EpisodeProgress` for episode `s1e5` (last of season 1), completed
- **AND** the series has a season 2 with episodes
- **WHEN** `execute(profile)` is called
- **THEN** the result has length 1
- **AND** the dto's episode is `s2e1`, kind == nextAfterCompleted

#### Scenario: Episode completed at end of series → restart

- **GIVEN** one `EpisodeProgress` for the last episode of the last season, completed
- **WHEN** `execute(profile)` is called
- **THEN** the dto's episode is the first episode of season 1
- **AND** kind == restart

#### Scenario: Specials are not part of the next-episode rotation

- **GIVEN** a series Pingu with Specials (season 0) and a regular
  season 1
- **AND** the user has completed the last episode of season 1
- **AND** there is no season 2
- **WHEN** `execute(profile)` is called
- **THEN** the result is `kind: restart` pointing to season 1 episode 1
- **AND** NOT a Specials episode

#### Scenario: Two progressions on the same series → most recent wins

- **GIVEN** two `EpisodeProgress` entries for series Pingu:
  - `s1e2` completed, `updatedAt = 2026-05-01`
  - `s1e3` in-progress, `updatedAt = 2026-05-04`
- **WHEN** `execute(profile)` is called
- **THEN** the result has length 1 (deduplicated)
- **AND** the kept item is `s1e3` in-progress (most recent updatedAt)

#### Scenario: SeriesRepository.findById throws → entry omitted, others kept

- **GIVEN** two `EpisodeProgress` entries, one for series A and one
  for series B
- **AND** `findById("seriesA")` throws an exception
- **AND** `findById("seriesB")` succeeds
- **WHEN** `execute(profile)` is called
- **THEN** the result contains only the seriesB entry
- **AND** no exception is propagated to the caller

#### Scenario: Mixed movie and episode entries are sorted by updatedAt desc

- **GIVEN**:
  - `MovieProgress(nemo, updatedAt: 2026-05-03)`
  - `EpisodeProgress(s1e3 of pingu, updatedAt: 2026-05-04)`
- **WHEN** `execute(profile)` is called
- **THEN** the resulting list is `[EpisodeContinueDto(pingu, s1e3),
  MovieContinueDto(nemo)]` (newest first)

---

### Requirement: ContinueWatchingItemDto sealed DTO

The system SHALL define a sealed DTO in
`lib/core/application/dtos/continue_watching_item.dto.dart`:

```dart
sealed class ContinueWatchingItemDto {
  String get id;            // movie.id or series.id (used as React-style key)
  int get resumeSeconds;
}

class MovieContinueDto extends ContinueWatchingItemDto {
  final MovieDto movie;
  final int resumeSeconds;
  final bool completed;
}

class EpisodeContinueDto extends ContinueWatchingItemDto {
  final SeriesDto series;
  final EpisodeDto episode;
  final int resumeSeconds;
  final ContinueWatchingState kind;  // inProgress | nextAfterCompleted | restart
}

enum ContinueWatchingState { inProgress, nextAfterCompleted, restart, never }
```

The `never` variant of `ContinueWatchingState` is unused inside
`ResolveContinueWatchingUseCase` itself (which only emits items for
profiles that have at least one progress) but is part of the public
state enum because the helper `resolveContinueWatchingForSeries` (see
above requirement) does return `never` when the user has never
started the series.

#### Scenario: MovieContinueDto carries the movie and resume position

- **GIVEN** a `MovieContinueDto` constructed with `movie: nemoDto,
  resumeSeconds: 1845, completed: false`
- **THEN** its fields hold those values verbatim

#### Scenario: EpisodeContinueDto carries series + episode

- **GIVEN** an `EpisodeContinueDto(series: pinguDto, episode: s1e3Dto,
  resumeSeconds: 240, kind: inProgress)`
- **THEN** its fields hold those values verbatim

---

### Requirement: StartEpisodePlaybackUseCase

The system SHALL define an Application-layer usecase
`StartEpisodePlaybackUseCase` in
`lib/core/application/usecases/start_episode_playback.usecase.dart`
that mirrors the existing `StartMoviePlaybackUseCase` for episodes.

The usecase SHALL:

1. Subscribe to `DownloadRepository.downloadEpisode(episode.id)`.
2. Open the player with the episode's local file when the stream
   reaches `DownloadStatus.readyToPlay` or `DownloadStatus.complete`.
3. Apply any prior `EpisodeProgress.positionSeconds` as the initial
   playback position (looked up via
   `WatchProgressRepository.findForEpisode`).
4. Persist updates via `WatchProgressRepository.save(EpisodeProgress(...))`
   with the same throttle/end-of-playback rules as
   `StartMoviePlaybackUseCase`.

The usecase SHALL NOT itself navigate or mount the player widget —
that is the UI's responsibility. The usecase exposes the stream and
position; the UI consumes them.

#### Scenario: Starts download on the episode endpoint

- **GIVEN** an episode `s1e3` of pingu
- **WHEN** the usecase is invoked
- **THEN** `DownloadRepository.downloadEpisode("s1e3")` is called
- **AND** `DownloadRepository.downloadMovie(...)` is NOT called

#### Scenario: Resumes from saved position

- **GIVEN** an `EpisodeProgress` exists for the active profile with
  `positionSeconds == 240` for episode `s1e3`
- **WHEN** the usecase is invoked
- **THEN** the player initial position is `240 seconds`

---

### Requirement: Series detail modal layout

The series detail modal SHALL be triggered by
`showCatalogItemDetail(context, series)` (the same entry point as the
movie modal — see `catalog` capability) and SHALL share the modal
presentation logic (`showModalBottomSheet` < 600dp, `showDialog`
≥ 600dp).

The modal SHALL contain, in order:

1. The same common header as the movie modal: backdrop, title,
   original title, tagline, meta line, synopsis, genres, directors,
   top 5 cast.
2. A primary "Lire" button whose label is computed by
   `playLabelFor(series, progresses)` (see next requirement).
3. A vertically stacked list of `_SeasonSection` widgets (one per
   season).

The meta line for a series SHALL show
`"{year} · {seasonsCount} saison(s) · {episodesCount} épisode(s)"`
(or a subset if `year` is null), replacing the movie modal's
`"{year} · {humanizedDuration} · {primaryGenre}"`.

The modal SHALL trigger
`seriesRepositoryProvider.findById(series.id)` on first display to
fetch the full hierarchy (the `series` instance arriving from the
catalog has empty `seasons`). While the future is pending, a skeleton
SHALL be shown in place of the season list (the header section is
displayed immediately with the data already known from catalog).

If the future fails (network, 404, 403), the season list area SHALL
display a centered error message with a Retry affordance that
re-invokes `findById`. The modal does NOT close on error — the user
can still see the metadata and retry.

#### Scenario: Modal triggers findById on open

- **GIVEN** a series `pingu` with empty `seasons`
- **WHEN** the modal is opened via `showCatalogItemDetail`
- **THEN** `seriesRepositoryProvider.findById("pingu")` is called once

#### Scenario: Header is shown immediately, season list shows skeleton

- **GIVEN** the modal is opening
- **AND** `findById` is still pending
- **THEN** the backdrop, title, synopsis are visible
- **AND** the season list area shows a skeleton placeholder

#### Scenario: Failed findById shows retry without closing

- **GIVEN** the modal is open and `findById` failed with a network error
- **WHEN** the user taps "Réessayer"
- **THEN** `findById` is invoked again
- **AND** the modal remains open

---

### Requirement: Season list ordering — Specials last

The series detail modal SHALL render seasons sorted by `seasonNumber`
ascending, EXCEPT that season 0 (Specials) — when present — SHALL be
moved to the end of the list.

#### Scenario: Specials are rendered last

- **GIVEN** a series with seasons `[0, 1, 2]` (Specials, Season 1, Season 2)
- **WHEN** the modal renders the season list
- **THEN** the visual order is `[Season 1, Season 2, Specials]`

#### Scenario: Series without Specials renders in numeric order

- **GIVEN** a series with seasons `[1, 2, 3]`
- **WHEN** the modal renders the season list
- **THEN** the visual order is `[Season 1, Season 2, Season 3]`

---

### Requirement: Default-expanded season is the most recently watched

The series detail modal SHALL deploy by default the
`ExpansionTile` corresponding to the season of the active profile's
most recent `EpisodeProgress` for this series (movies aside).

If the profile has never started this series, the modal SHALL deploy
season 1 by default (the lowest non-zero season number).

If the most recent progress points to a Specials episode (season 0),
the modal SHALL still deploy that season — the rendering reordering
(Specials last in the list) is independent of which one is expanded.

All other seasons SHALL be collapsed.

#### Scenario: Default expands season of most recent episode progress

- **GIVEN** the active profile's most recent `EpisodeProgress` for
  pingu is `s2e3`
- **WHEN** the modal opens
- **THEN** Season 2's expansion tile is open
- **AND** Seasons 1 and Specials are collapsed

#### Scenario: Default expands Season 1 when no progress exists

- **GIVEN** the active profile has no `EpisodeProgress` for pingu
- **WHEN** the modal opens
- **THEN** Season 1's expansion tile is open

---

### Requirement: Episode card layout

Each episode in the season list SHALL be rendered as a card
displaying:

- The episode `thumbUrl` rendered as a 16:9 image (with a neutral grey
  fallback when null).
- A reference label `"E{episodeNumber}"` (or `"S{seasonNumber}E{episodeNumber}"`
  for Specials, since season 0's episodes don't have a natural place
  in the per-season list — they appear in the Specials section).
- The episode `title` (1 line, ellipsis on overflow).
- A caption showing the humanized `duration` (using the same
  `lib/shared/duration_format.dart` formatter as movie cards).

When an `EpisodeProgress` exists for the active profile and this
episode:

- A linear progress bar SHALL be overlaid at the bottom of the
  thumbnail showing `positionSeconds / duration.inSeconds`.
- If `progress.completed == true`, a check (`✓`) icon SHALL be
  overlaid in the top-right corner of the thumbnail.

Tapping the card SHALL invoke `StartEpisodePlaybackUseCase` directly
on this episode (no intermediate modal).

#### Scenario: Episode card without progress shows just thumb + title + duration

- **GIVEN** an episode with `thumbUrl` non-null, `duration = 5min`
- **AND** no `EpisodeProgress` for the active profile
- **WHEN** rendered
- **THEN** the card shows the thumb, the title, the caption "E{n} · 5 min"
- **AND** there is no progress bar overlay
- **AND** there is no completion check overlay

#### Scenario: Episode card with in-progress shows progress bar

- **GIVEN** an episode of duration 300 seconds
- **AND** an `EpisodeProgress` with `positionSeconds = 120`, `completed = false`
- **WHEN** rendered
- **THEN** a progress bar is overlaid at 40% fill
- **AND** no completion check is shown

#### Scenario: Episode card with completed shows check

- **GIVEN** an episode with `EpisodeProgress.completed = true`
- **WHEN** rendered
- **THEN** a `✓` icon overlay is shown
- **AND** the progress bar overlay shows 100% fill (or is omitted —
  implementation choice, scenario tolerant)

#### Scenario: Tapping an episode card starts playback directly

- **GIVEN** a visible episode card
- **WHEN** the user taps the card
- **THEN** `StartEpisodePlaybackUseCase.execute(episode)` is invoked
- **AND** no intermediate modal opens

---

### Requirement: Smart "Lire" button label

The series detail modal SHALL render its primary "Lire" button with a
dynamic label computed by the helper
`playLabelFor(series, progresses) -> ({String label, Episode target})`
in `lib/ui/catalog/series/play_label.dart`.

The helper SHALL delegate to the Application helper
`resolveContinueWatchingForSeries(series, latestEpisodeProgress)` to
determine the `ContinueWatchingState` and the target episode, then
format the label as follows:

| State | Label |
|---|---|
| `never` | `"Lire S{firstEp.seasonNumber}E{firstEp.episodeNumber}"` |
| `inProgress` | `"Reprendre S{ep.seasonNumber}E{ep.episodeNumber}"` |
| `nextAfterCompleted` | `"Lire S{nextEp.seasonNumber}E{nextEp.episodeNumber}"` |
| `restart` | `"Revoir S{firstEp.seasonNumber}E{firstEp.episodeNumber}"` |

For the `never` and `restart` states, `firstEp` is the first episode
of the lowest non-zero season (Specials are excluded from this
rotation, consistent with the usecase requirement).

Tapping the button SHALL invoke `StartEpisodePlaybackUseCase` on the
returned `target` episode. The resume position is provided by the
caller (zero for `never` / `nextAfterCompleted` / `restart`,
`progress.positionSeconds` for `inProgress`).

#### Scenario: Never-watched series shows "Lire S1E1"

- **GIVEN** a series with first non-zero season = 1, first episode = 1
- **AND** no `EpisodeProgress` for the active profile
- **WHEN** the label is computed
- **THEN** the label is `"Lire S1E1"`

#### Scenario: In-progress shows "Reprendre"

- **GIVEN** an `EpisodeProgress` on `s2e5`, in progress
- **WHEN** the label is computed
- **THEN** the label is `"Reprendre S2E5"`

#### Scenario: Completed mid-season shows "Lire S{n}E{m+1}"

- **GIVEN** an `EpisodeProgress` on `s2e5`, completed, with `s2e6` existing
- **WHEN** the label is computed
- **THEN** the label is `"Lire S2E6"`

#### Scenario: Series fully watched shows "Revoir S1E1"

- **GIVEN** an `EpisodeProgress` on the last episode of the last
  non-Specials season, completed
- **WHEN** the label is computed
- **THEN** the label is `"Revoir S1E1"`

---

### Requirement: Continue Watching row supports mixed movie / series cards

The Continue Watching row on the homepage SHALL render a mixed list
of cards reflecting the output of `ResolveContinueWatchingUseCase`:

- A `MovieContinueDto` SHALL render as a standard `CatalogItemCard`
  (the existing movie poster + title + caption layout) with a linear
  progress bar overlaid at the bottom of the poster reflecting
  `resumeSeconds / movie.duration.inSeconds`. Tapping opens the movie
  detail modal as usual.
- An `EpisodeContinueDto` SHALL render as a series-specific card:
  - The thumbnail SHALL be the episode's `thumbUrl` (with the series'
    `backdropUrl` as fallback when `thumbUrl` is null, and a neutral
    grey when both are null).
  - The primary label SHALL be the episode reference + title:
    `"S{n}E{m} · {episode.title}"` (truncated to one line).
  - The secondary label SHALL be the `series.title`.
  - A linear progress bar SHALL overlay the bottom of the thumbnail
    reflecting `resumeSeconds / episode.duration.inSeconds` when
    `kind == inProgress` ; for `nextAfterCompleted` and `restart`,
    no progress bar is shown.
  - Tapping the card SHALL invoke `StartEpisodePlaybackUseCase`
    directly with the resume position (NOT open the series detail
    modal — direct playback aligns with the user's intent of "resume
    where I left off").

#### Scenario: Movie continue card opens movie modal on tap

- **GIVEN** a `MovieContinueDto` for `nemo`
- **WHEN** the user taps the card
- **THEN** the movie detail modal for `nemo` opens
- **AND** the player is NOT started directly

#### Scenario: Episode continue card starts playback on tap

- **GIVEN** an `EpisodeContinueDto` for series `pingu`, episode `s1e3`,
  `resumeSeconds = 240`
- **WHEN** the user taps the card
- **THEN** `StartEpisodePlaybackUseCase.execute(s1e3)` is invoked
- **AND** the resume position passed to the player is `240 seconds`
- **AND** the series detail modal does NOT open

#### Scenario: Episode continue card label shows S{n}E{m} · title

- **GIVEN** an `EpisodeContinueDto` whose episode is `s2e3` with title `"Voyage"`
- **WHEN** the card is rendered
- **THEN** the primary label reads `"S2E3 · Voyage"` (one line, ellipsis
  on overflow)

#### Scenario: nextAfterCompleted card has no progress bar

- **GIVEN** an `EpisodeContinueDto` with `kind == nextAfterCompleted`
- **WHEN** the card is rendered
- **THEN** no progress bar is overlaid on the thumbnail

---

### Requirement: HomePage shows mixed-kind catalog with series in Recently Added

The homepage's `recentlyAdded` row SHALL include both films and series
sorted by `addedAt` descending, capped at the same 20-item limit as
films-only (catalog requirement).

The other rows continue to be film-only at MVP:
- `saga` — only `Movie` items.
- `genre` — only `Movie` items.
- `favorites` — only `Movie` items.
- `neverWatched` — only `Movie` items.
- `downloaded` — only `Movie` items.

The `continueWatching` row is mixed (see previous requirement, fed by
`ResolveContinueWatchingUseCase`).

The application service `CatalogApplicationService` SHALL filter the
mixed `List<CatalogItem>` from `repo.listCatalog()` via
`items.whereType<Movie>()` for the film-only rows.

#### Scenario: Recently Added row mixes movies and series

- **GIVEN** the catalog returns `[Movie(addedAt: 2026-05-04), Series(addedAt: 2026-05-03)]`
- **WHEN** the homepage builds rows
- **THEN** the `recentlyAdded` row contains both items
- **AND** they are ordered `[Movie, Series]` (movie added later)

#### Scenario: Genre row excludes series

- **GIVEN** the catalog returns a `Movie(genres: ["Animation"])` and a
  `Series(genres: ["Animation"])`
- **WHEN** the homepage builds rows
- **THEN** the `genre: "Animation"` row contains only the movie
- **AND** the series is NOT present in any genre row

### Requirement: SeriesRepository.findByIdForProfile

The system SHALL extend `SeriesRepository` with a profile-explicit
lookup method:

```dart
Future<Series> findByIdForProfile(String seriesId, String profileId);
```

The method SHALL return the [Series] identified by [seriesId] with
its full `seasons` / `episodes` hierarchy, on behalf of [profileId]
rather than the currently-active profile.

The method exists for the downloads manager: when a kid downloads an
episode of a series with `age_category` above the parent's, the
parent's `findById` call would fail with a `403 forbidden_age_category`
(per `API.md` § Détail d'une série). The manager calls
`findByIdForProfile` with the kid profile id — known via
`CatalogRepository.listCatalogForProfile` (cf. `catalog` capability
delta) — to get the full series tree.

* The HTTP implementation SHALL issue `GET /series/{seriesId}` with
  `X-Profile-Id: $profileId` pre-set on the per-call
  `Options.headers`. The `AuthInterceptor` SHALL preserve the
  override (cf. catalog capability delta).
* The in-memory implementation SHALL behave identically to
  `findById` (no profile filter at this layer).

#### Scenario: HTTP impl uses the per-call profile header

- **GIVEN** the active profile is `"parent"` (age `adulte`)
- **AND** series `"pingu"` has `age_category == bebe`, exposed only to profile `"marie"`
- **WHEN** `findByIdForProfile("pingu", "marie")` is called
- **THEN** the outbound `GET /series/pingu` carries `X-Profile-Id: marie`
- **AND** the response is parsed into a [Series] with seasons + episodes

#### Scenario: In-memory impl ignores the profile id

- **GIVEN** the in-memory repo is in use
- **WHEN** `findByIdForProfile("pingu", "any-id")` is called
- **THEN** the result is identical to `findById("pingu")`

