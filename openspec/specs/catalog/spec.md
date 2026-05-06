# Catalog

## Purpose

Consultation du catalogue de films disponible pour le profil actif depuis la
homepage. Organise les films en rows thématiques (nouveautés, genres, sagas,
statut de lecture) empilées verticalement avec scroll horizontal intra-row.
Couvre le modèle Domain du film, l'interface de repository, la composition
applicative des rows, et l'UI de la homepage + modale de détails. Ne couvre
PAS la lecture vidéo, le téléchargement, la reprise de lecture, ni la gestion
des favoris utilisateur-curated — ces capacités relèvent de changes
ultérieurs.
## Requirements
### Requirement: Movie domain model

The system SHALL represent a movie as an immutable Domain entity
`Movie` defined in `lib/core/domain/model/media.dart` (no longer in
`movie.dart` — the file is removed in this change due to the Dart
sealed-class library constraint requiring all subtypes to live in the
same library).

`Movie` SHALL `extends CatalogItem` and `implements PlayableMedia` (the
latter from the `series-viewing` capability). Its fields are unchanged
from the prior version of this capability:

- `id`, `title`, `originalTitle`, `year`, `duration`, `synopsis`,
  `tagline`, `posterUrl`, `backdropUrl`, `ageCategory`, `genres`,
  `sagaId`, `sagaLabel`, `director`, `cast`, `addedAt`.

Equality remains by `id` ; `hasSaga`, `primaryGenre` accessors are
preserved.

`CastMember` SHALL also live in `media.dart` (moved alongside `Movie`
for the same library-membership reason).

#### Scenario: Movie is a CatalogItem

- **GIVEN** a `Movie` instance
- **THEN** `movie is CatalogItem` is true

#### Scenario: Movie is a PlayableMedia

- **GIVEN** a `Movie` instance
- **THEN** `movie is PlayableMedia` is true

#### Scenario: Movie equality by id is preserved

- **GIVEN** two `Movie` instances with the same `id` but different
  field values otherwise
- **THEN** they are equal

---

### Requirement: CatalogRow and CatalogRowType model

The system SHALL represent a row as an immutable data class
`CatalogRow` with the following fields:

- `label`: display label shown above the row (non-empty string).
- `type`: `CatalogRowType` enum value.
- `items`: ordered `List<CatalogItem>` — may be empty, may mix
  `Movie` and `Series` instances depending on the row type.

The field is renamed from `movies: List<Movie>` to `items: List<CatalogItem>`.
Sites that previously accessed `row.movies` SHALL be updated to
`row.items`. Sites that depended on the static type `List<Movie>`
SHALL switch on the `CatalogItem` sealed or use `whereType<Movie>()`
when they specifically need movies.

The `CatalogRowType` enum is unchanged — same seven variants
(`continueWatching`, `recentlyAdded`, `favorites`, `saga`, `genre`,
`neverWatched`, `downloaded`).

For rows of type `saga` and `genre`, the application service emits
**only `Movie` instances** at MVP (see "Row composition includes /
excludes series" requirement below). For `recentlyAdded` and
`continueWatching`, both kinds may appear.

#### Scenario: CatalogRow can hold mixed Movies and Series

- **WHEN** a `CatalogRow` is constructed with `items = [movie, series, movie]`
- **THEN** it is a valid instance and the field type accepts both kinds

#### Scenario: CatalogRow can be empty

- **WHEN** a `CatalogRow` is constructed with `items = []`
- **THEN** it is a valid instance
- **AND** the UI layer is responsible for hiding it (see empty-row requirement)

---

### Requirement: Catalog repository returns raw movies per age category

The system SHALL define a Domain interface `CatalogRepository`. For
homepage composition, it exposes:

```dart
Future<List<CatalogItem>> listCatalog();
```

The method is renamed from `listMoviesFor()` and now returns a
heterogeneous list of `Movie` and `Series` instances (the wire payload
discriminates via `kind`).

The repository SHALL return all catalog items the active profile is
allowed to see. The filter is applied **outside the repository**:

- HTTP : the backend filters server-side via `X-Profile-Id` (returning
  only items whose `ageCategory == profile.ageCategory`). The
  repository sends `GET /catalog` with no query parameters.
- In-memory : no filter is applied — the repository returns the full
  seeded list (movies + series) regardless of the active profile.

The repository SHALL NOT know about rows, grouping, or the active
profile. The signature `listCatalog()` (no parameter) is the wire
guarantee that the repository has no profile-awareness.

The in-memory implementation SHALL seed at least 10 fictional movies
distributed across all five age categories (unchanged from prior
versions) **plus** at least one series in the `enfant` category (the
Pingu seed defined in the `series-viewing` capability).

#### Scenario: In-memory repository returns the full seeded catalog

- **GIVEN** an `InMemoryCatalogRepository` containing movies across all
  age categories plus the Pingu series
- **WHEN** `listCatalog()` is called
- **THEN** the returned list contains every seeded movie and every
  seeded series
- **AND** no item is filtered out at the repository layer

#### Scenario: HTTP repository sends GET /catalog with no query parameters

- **GIVEN** a `DioCatalogRepository` whose `Dio` has `baseUrl ==
  "http://test.local"`
- **AND** the backend responds 200 with `{"items": [<movie1>,
  <series1>]}`
- **WHEN** `listCatalog()` is called
- **THEN** the request method is `GET` on path `/catalog`
- **AND** the request has no query parameters
- **AND** the future completes with a `List<CatalogItem>` of length 2
  whose first element is a `Movie` and second is a `Series` (per the
  `kind` discriminator)

#### Scenario: HTTP repository preserves backend item order

- **GIVEN** the backend responds with `{"items": [<series_a>,
  <movie_b>, <series_c>]}`
- **WHEN** `listCatalog()` is called
- **THEN** the returned list is in the same order
  `[seriesA, movieB, seriesC]`

---

### Requirement: Homepage catalog is composed by an application service

The system SHALL expose an Application-layer service
`CatalogApplicationService` with a method:

```dart
Future<List<CatalogRowDto>> buildHomeRowsFor(ProfileDto profile);
```

The service SHALL:

1. Call `CatalogRepository.listCatalog()` to get the raw mixed catalog
   items available to the active profile.
2. **In parallel** (`Future.wait`), call
   `ResolveContinueWatchingUseCase.execute(profile)` (defined in the
   `series-viewing` capability) to compute the Continue Watching row.
3. Assemble a list of `CatalogRow` instances following these
   composition rules:
   - `continueWatching` row : items come directly from the usecase
     output (mixed `MovieContinueDto` / `EpisodeContinueDto`, exposed
     via `CatalogItemDto` projection).
   - `recentlyAdded` row : both `Movie` and `Series` from `listCatalog`,
     sorted by `addedAt` desc, capped at 20.
   - `favorites`, `neverWatched`, `downloaded`, `saga`, `genre` rows :
     only `Movie` items (`whereType<Movie>()` filter applied).
4. Apply the fixed row ordering (unchanged sequence).
5. Convert each `CatalogRow` into a `CatalogRowDto` (containing
   `List<CatalogItemDto>` or its sealed equivalent).
6. Return only rows with at least one item (empty rows filtered out).

The service SHALL NOT pass `profile.ageCategory` to the repository
(unchanged from `add-profile-aware-permissions`).

The usecase `ListHomeCatalogUseCase` SHALL continue to wrap the service
call with no signature change.

#### Scenario: Service returns only non-empty rows

- **GIVEN** a profile with no progress and no catalog items
- **WHEN** `buildHomeRowsFor(profile)` is called
- **THEN** the returned list is empty

#### Scenario: Recently Added mixes movies and series

- **GIVEN** the catalog returns `[Movie(addedAt: 2026-05-04),
  Series(addedAt: 2026-05-03)]`
- **WHEN** rows are built
- **THEN** the `recentlyAdded` row contains both items
- **AND** the order is `[Movie, Series]`

#### Scenario: Saga row excludes series

- **GIVEN** the catalog returns two movies sharing `sagaId =
  "asterix"` and a series with the same `sagaId`
- **WHEN** rows are built
- **THEN** the saga row contains only the two movies (the series is
  filtered out)

#### Scenario: Genre row excludes series

- **GIVEN** the catalog returns a `Movie(genres: ["Animation"])` and a
  `Series(genres: ["Animation"])`
- **WHEN** rows are built
- **THEN** the `genre: "Animation"` row contains only the movie

#### Scenario: Continue Watching uses ResolveContinueWatchingUseCase

- **GIVEN** the active profile has progress on `nemo` and on episode
  `s1e3` of pingu
- **WHEN** `buildHomeRowsFor(profile)` is called
- **THEN** the `continueWatching` row is populated by the result of
  `ResolveContinueWatchingUseCase.execute(profile)` (verified by
  injecting a fake usecase and asserting its `execute` was called)

---

### Requirement: Empty rows are hidden from the homepage

The homepage SHALL NOT display any row whose `movies` list is empty. This
applies to all row types including dynamic ones (saga, genre).

The empty-filtering SHALL occur in the `CatalogApplicationService` so the
UI receives only non-empty rows.

#### Scenario: Row with zero movies is absent from output

- **GIVEN** a catalog where no movie is marked as "continue watching"
- **WHEN** `buildHomeRowsFor(profile)` is called
- **THEN** no row of type `continueWatching` is present in the returned list

---

### Requirement: Strict age category filter on the homepage

The homepage SHALL expose ONLY movies whose `ageCategory` is appropriate for the active profile. The decision of "appropriate" SHALL live **outside the front-end repository**:

- In the HTTP mode (production), the backend filters server-side based on the `X-Profile-Id` header. The contract specified by `add-profile-permissions` (server-side) is: only movies whose `ageCategory == profile.ageCategory` are returned. Hierarchical access (lower age categories visible to higher-tier profiles) is OUT OF SCOPE for the homepage on both sides — it is handled by the `search` capability, which allows a profile to find movies with `ageCategory ≤ profile.ageCategory` via the search bar.
- In the in-memory mode (dev/test), no filter is applied. The homepage shows every seeded movie. This is an accepted regression of the dev experience for the sake of architectural clarity (the repository has no profile-awareness). Validation of the strict-equality filter is the backend's responsibility and is covered by HTTP integration tests / backend tests, not by the in-memory front-end repo.

This requirement SHALL not be interpreted as imposing a client-side post-filter. The `CatalogApplicationService` SHALL NOT re-filter `repo.listMoviesFor()` by `profile.ageCategory` — doing so would duplicate the backend's responsibility and would mask in-memory behaviour in tests.

#### Scenario: Ado profile sees only ado movies on the homepage in HTTP mode

- **GIVEN** an active profile with `ageCategory == AgeCategory.ado` and `id == "ro"`
- **AND** the app is running in HTTP mode (`API_BASE_URL` non-empty)
- **AND** the backend honours `X-Profile-Id: ro` by returning only `ado` movies on `GET /movies`
- **WHEN** the homepage is built for this profile
- **THEN** all movies displayed on the homepage have `ageCategory == AgeCategory.ado`

#### Scenario: In-memory mode shows all seeded movies regardless of active profile

- **GIVEN** an active profile with `ageCategory == AgeCategory.enfant`
- **AND** the app is running in in-memory mode (`API_BASE_URL` empty)
- **AND** the in-memory seed contains movies from all five age categories
- **WHEN** the homepage is built for this profile
- **THEN** the homepage displays movies from all five age categories
- **AND** this is the documented dev-mode behaviour, not a regression to fix

---

### Requirement: Saga row requires at least two movies sharing the same saga

The application service SHALL emit a `CatalogRow` of type `saga` for a given
saga if, and only if, at least two movies in the filtered catalog share the
same non-null `sagaId`.

The row's `label` SHALL be the `sagaLabel` of those movies.

A single standalone movie with a `sagaId` SHALL NOT create a saga row; it
is available through other rows (recentlyAdded, genre).

#### Scenario: Two Astérix movies create a saga row

- **GIVEN** the filtered catalog contains two movies with `sagaId = "asterix"` and `sagaLabel = "Astérix"`
- **WHEN** rows are built
- **THEN** a row of type `saga` with label `"Astérix"` and those two movies is present

#### Scenario: A single sagaId movie does not create a saga row

- **GIVEN** the filtered catalog contains exactly one movie with `sagaId = "harry-potter"`
- **WHEN** rows are built
- **THEN** no row of type `saga` is emitted for `"harry-potter"`

---

### Requirement: Genre rows group movies by their primary genre only

The application service SHALL emit a `CatalogRow` of type `genre` for each
distinct first genre in `movie.genres` present in the filtered catalog.

A movie with multiple genres SHALL appear in ONE genre row only — the row
corresponding to `movie.genres.first`.

The row's `label` SHALL be the primary genre string itself (e.g.,
`"Animation"`, `"Comédie"`).

#### Scenario: Movie with four genres appears in only one genre row

- **GIVEN** a movie with `genres = ["Familial", "Comédie", "Aventure", "Fantastique"]`
- **WHEN** rows are built
- **THEN** the movie is present in the `"Familial"` genre row only
- **AND** it is NOT present in the `"Comédie"`, `"Aventure"`, or `"Fantastique"` genre rows

#### Scenario: Two distinct primary genres produce two genre rows

- **GIVEN** one movie with primary genre `"Animation"` and another with primary genre `"Aventure"`
- **WHEN** rows are built
- **THEN** two genre rows are emitted, one per primary genre

---

### Requirement: Row display order is fixed

The application service SHALL order the returned rows according to the
following fixed sequence:

1. `continueWatching`
2. `recentlyAdded`
3. `favorites`
4. all `saga` rows, sorted by movie count **descending** (ties broken by
   saga label, alphabetical ascending)
5. all `genre` rows, sorted by genre label **alphabetical ascending**
6. `neverWatched`
7. `downloaded`

Rows filtered out as empty SHALL be removed after ordering (see empty-row
requirement). The resulting order is preserved exactly as emitted by the
service — the UI SHALL NOT re-sort.

#### Scenario: continueWatching row, when present, comes first

- **GIVEN** a catalog producing rows of types `continueWatching`, `recentlyAdded`, and two saga rows
- **WHEN** rows are built
- **THEN** the first row returned has type `continueWatching`
- **AND** the second row has type `recentlyAdded`

#### Scenario: Larger sagas precede smaller sagas

- **GIVEN** a saga "Pixar" with 5 movies and a saga "Astérix" with 2 movies in the filtered catalog
- **WHEN** rows are built
- **THEN** the "Pixar" saga row appears before the "Astérix" saga row

#### Scenario: Genre rows are alphabetical

- **GIVEN** three genre rows with labels `"Comédie"`, `"Animation"`, `"Aventure"`
- **WHEN** rows are built
- **THEN** the order is `"Animation"`, `"Aventure"`, `"Comédie"`

---

### Requirement: Movies inside a row are sorted deterministically

Within each row, movies SHALL be ordered as follows:

- `recentlyAdded`: by `addedAt` descending (newest first). The row SHALL
  include at most the 20 most recently added movies.
- `saga`: by `year` ascending (oldest first, natural saga chronology). Ties
  broken by `title` ascending.
- `genre`: by `title` ascending.
- `continueWatching`, `favorites`, `neverWatched`, `downloaded`: preserved
  in the order provided by the underlying source (for MVP stubs, insertion
  order).

#### Scenario: Recently added row caps at 20 movies

- **GIVEN** a filtered catalog with 37 movies
- **WHEN** the `recentlyAdded` row is built
- **THEN** the row contains exactly 20 movies
- **AND** those 20 are the ones with the most recent `addedAt`

#### Scenario: Saga row ordered by year ascending

- **GIVEN** three saga movies with years `2012`, `2002`, `2023`
- **WHEN** the saga row is built
- **THEN** the movie order is `2002`, `2012`, `2023`

---

### Requirement: Homepage displays a vertically stacked list of rows

The homepage SHALL display rows as a vertical scroll of horizontal rows.
Each row SHALL expose its label above the horizontal list of movie cards.

A horizontal row SHALL scroll independently of the vertical page scroll.

The homepage SHALL also expose, in its `AppBar`, the "Changer de profil"
action defined by the `profile-selection` capability — this requirement is
unchanged by the catalog feature.

#### Scenario: Two rows scroll independently

- **GIVEN** a homepage with two visible rows each containing 10 movies
- **WHEN** the user swipes horizontally on the first row
- **THEN** only the first row's movies scroll horizontally
- **AND** the second row's horizontal scroll position is unchanged

---

### Requirement: Movie card shows poster, title, and year · duration

Each movie in a row SHALL be rendered as a card displaying:

- A poster image (ratio 2:3) loaded from `Movie.posterUrl` when non-null,
  with a neutral grey fallback otherwise.
- The `title` below the poster, on a single line, truncated with an
  ellipsis if too long.
- Under the title, a single caption line in the format `"YYYY · Xh YY"`
  or `"YYYY · XX min"` depending on runtime (see duration format
  requirement). If `year` is null, the caption SHALL be only the duration.

Tapping a card SHALL open the movie detail modal (see modal requirement).

#### Scenario: Card without year shows duration only

- **GIVEN** a movie with `year = null` and `duration = 112 min`
- **WHEN** the card is rendered
- **THEN** the caption shows `"1h52"` only (no bullet, no year)

#### Scenario: Tapping a card opens the detail modal

- **GIVEN** a visible movie card
- **WHEN** the user taps the card
- **THEN** the movie detail modal appears for that movie

---

### Requirement: Humanized duration format

The UI SHALL format a `Duration` for display with the following rules:

- Duration `< 60 minutes` → `"X min"` where `X` is the integer number of
  minutes (e.g., `"42 min"`).
- Duration `>= 60 minutes` → `"XhYY"` where `X` is integer hours and `YY`
  is the remaining minutes zero-padded to two digits (e.g., `"1h52"`,
  `"2h05"`). No whitespace between hour and minutes (French convention).

The formatter SHALL be a pure function in `lib/shared/duration_format.dart`.

#### Scenario: Under one hour

- **WHEN** formatting a duration of `42 minutes`
- **THEN** the returned string is `"42 min"`

#### Scenario: Over one hour with minute leftover

- **WHEN** formatting a duration of `112 minutes`
- **THEN** the returned string is `"1h52"`

#### Scenario: Exactly one hour

- **WHEN** formatting a duration of `60 minutes`
- **THEN** the returned string is `"1h00"`

#### Scenario: Hour with single-digit minute padded

- **WHEN** formatting a duration of `65 minutes`
- **THEN** the returned string is `"1h05"`

---

### Requirement: Movie detail modal is adaptive and presents full metadata

Tapping a movie card SHALL open a modal showing the movie details. The
modal presentation SHALL be selected at call time based on screen width:

- Screen width `< 600 dp` → `showModalBottomSheet(isScrollControlled: true)`,
  presented as a near-fullscreen sheet rising from the bottom.
- Screen width `>= 600 dp` → `showDialog`, presented as a centered dialog
  capped at 720 dp wide.

The modal content SHALL be identical across presentation modes and SHALL
contain, in order:

1. `backdropUrl` rendered as a full-width image (or a solid placeholder
   when null).
2. `title`, optionally followed by `originalTitle` in a secondary style if
   different.
3. `tagline` if present.
4. A meta line combining `year` (if present), humanized `duration`, and
   primary genre.
5. `synopsis`.
6. `genres` — all, as a chip list or comma-separated line.
7. `director` — all names, comma-separated.
8. Top 5 cast members (first five entries of `cast`), each showing `name`
   and `role` if present.
9. A "Lire" (Play) button styled as a primary filled button (see play-
   button requirement).

The modal SHALL be dismissible by:

- Tapping a close affordance.
- Swiping down (bottom-sheet mode).
- Tapping outside / pressing Escape (dialog mode).

#### Scenario: Modal on mobile

- **GIVEN** an active homepage at screen width `375 dp`
- **WHEN** the user taps a movie card
- **THEN** a `ModalBottomSheet` rises from the bottom
- **AND** its content includes the title, tagline, synopsis, and Play button

#### Scenario: Modal on desktop

- **GIVEN** an active homepage at screen width `1440 dp`
- **WHEN** the user taps a movie card
- **THEN** a `Dialog` is shown centered on screen
- **AND** its content is identical to the mobile presentation

#### Scenario: Cast trimmed to five members

- **GIVEN** a movie with 40 cast entries
- **WHEN** the detail modal is rendered
- **THEN** only the first 5 cast members are visible

---

### Requirement: Posters are cached on disk for offline availability

The UI SHALL load poster and backdrop images through `cached_network_image`
(added as a `pubspec.yaml` dependency).

Once an image has been fetched successfully, a subsequent display SHALL
render the cached copy from disk, including when the device has no network
connectivity.

During the first fetch, a shimmer-style placeholder SHALL be displayed in
the image area. If the fetch fails, a neutral grey fallback SHALL be
displayed.

#### Scenario: Cached poster survives offline

- **GIVEN** a poster has been rendered once while online
- **WHEN** the device goes offline
- **AND** the same poster is rendered again
- **THEN** the cached image is displayed from disk with no network call

#### Scenario: Failed poster shows fallback

- **GIVEN** a poster URL returns HTTP 404
- **WHEN** the card is rendered
- **THEN** a neutral grey fallback replaces the image
- **AND** the surrounding card layout is unaffected

---

### Requirement: Homepage renders loading, empty, and content states

While `ListHomeCatalogUseCase` is pending, the homepage SHALL render an
animated skeleton simulating two placeholder rows of four cards each. The
skeleton SHALL animate by alternating opacity on a standard Flutter Tween
(no third-party dependency).

When the usecase completes successfully with a non-empty list, the homepage
SHALL render the rows.

When the usecase completes successfully with an empty list (no movies
match the profile's age category), the homepage SHALL render a centered
empty state showing the message
`"Aucun film disponible pour ce profil pour le moment."`.

When the usecase fails, the homepage SHALL render an error state with a
retry affordance that re-triggers the usecase.

#### Scenario: Skeleton is displayed during loading

- **GIVEN** the homepage has just been opened for a profile
- **WHEN** `ListHomeCatalogUseCase` is pending
- **THEN** two skeleton rows of four animated grey cards are shown

#### Scenario: Empty state message for bebe profile with no matching movie

- **GIVEN** a profile with `ageCategory == AgeCategory.bebe`
- **AND** the catalog contains no `bebe` movie
- **WHEN** the usecase completes with an empty list
- **THEN** the homepage shows the centered message
  `"Aucun film disponible pour ce profil pour le moment."`
- **AND** no row widgets are shown

#### Scenario: Error state exposes retry

- **GIVEN** the usecase has failed (e.g., repository exception)
- **WHEN** the user taps the "Réessayer" button
- **THEN** the usecase is re-invoked with the same profile

---

### Requirement: In-memory repository provides MVP stubs for all row types

For this change, the `InMemoryCatalogRepository` SHALL provide hard-coded
stub data sufficient to populate every non-empty row type on the homepage,
including rows that depend on features not yet implemented (player,
favorites, downloads).

The stubs for `continueWatching`, `favorites`, `neverWatched`, and
`downloaded` rows SHALL be implemented in the `CatalogApplicationService`
as sub-lists of the filtered catalog (e.g., arbitrary slices marked with
explicit `// TODO(MVP): replace with real repository` comments).

When the corresponding real capabilities land, the stub helpers SHALL be
replaced by dependencies on dedicated repositories (`WatchProgressRepository`,
`FavoritesRepository`, `DownloadsRepository`) introduced in those changes.
This change SHALL NOT introduce those repositories preemptively.

#### Scenario: Every stub row is populated on MVP launch

- **GIVEN** an active `enfant` profile with ≥ 6 `enfant` movies in the in-memory catalog
- **WHEN** the homepage is built
- **THEN** the `continueWatching`, `favorites`, `neverWatched`, and `downloaded` rows each contain at least 1 movie

### Requirement: Catalog repository supports hierarchical search by title

The `CatalogRepository` Domain interface SHALL expose a second method
used by the `search` capability:

```dart
Future<List<CatalogItem>> searchCatalog({required String query});
```

The method is renamed from `searchMovies` and now returns mixed
movies and series.

The method SHALL return every catalog item whose normalized `title`
OR normalized `originalTitle` (when non-null) contains the normalized
`query` as a substring. Normalization is case- and
accent-insensitive (NFD + strip diacritics + lowercase ; applied
symmetrically server-side).

The age-hierarchy filter (`item.ageCategory ≤ active profile age
category`) is applied **outside the repository** as before:

- HTTP : the backend filters server-side via `X-Profile-Id`. The
  repository sends `GET /catalog/search?q=<query>` (route renamed
  from `/movies/search`).
- In-memory : no age filter is applied.

The repository SHALL NOT know about rows, the active profile, sorting,
or debouncing. Sorting and debouncing remain the responsibility of
the `SearchApplicationService` and the UI controller respectively.

#### Scenario: searchCatalog returns matches across both kinds

- **GIVEN** an `InMemoryCatalogRepository` containing a `Movie` "Pikachu"
  and a `Series` "Pingu"
- **WHEN** `searchCatalog(query: "pi")` is called
- **THEN** the returned list contains both items

#### Scenario: HTTP searchCatalog sends GET /catalog/search

- **GIVEN** a `DioCatalogRepository` whose `Dio` has `baseUrl ==
  "http://test.local"`
- **AND** the backend responds 200 with `{"items": []}`
- **WHEN** `searchCatalog(query: "astérix")` is called
- **THEN** the request method is `GET` on path `/catalog/search`
- **AND** the request has query parameter `q == "astérix"` (raw,
  accents preserved)
- **AND** the request has NO other query parameter

---

### Requirement: Shared wire helpers for AgeCategory

The system SHALL expose two public top-level functions in `lib/core/application/dtos/age_category_wire.dart`:

- `AgeCategory ageCategoryFromWire(String value)` — parses the snake_case wire string into an `AgeCategory` Domain enum.
- `String ageCategoryToWire(AgeCategory value)` — serializes an `AgeCategory` Domain enum into its snake_case wire string.

The mapping SHALL be:

| `AgeCategory` | Wire string |
|---|---|
| `bebe` | `"bebe"` |
| `enfant` | `"enfant"` |
| `ado` | `"ado"` |
| `jeuneAdulte` | `"jeune_adulte"` |
| `adulte` | `"adulte"` |

`ageCategoryFromWire` SHALL throw `FormatException('Unknown age_category: <value>')` when given a string that does not match any of the five wire values. This is a fail-fast guard: any deviation indicates a contract bug between client and backend, and the exception SHALL propagate uncaught so it surfaces during dev/test rather than being silently mapped to a default.

The two functions SHALL replace the previously-private `_ageCategoryFromWire` and the previously-public `ageCategoryToWire` that lived in `lib/core/application/dtos/remote_profile.dto.dart`. After this change, the helpers no longer reside in any single capability's DTO file — they are generic wire helpers shared by all `Remote*Dto` parsers (currently: `RemoteProfileDto`, `RemoteMovieDto`).

The file SHALL NOT depend on any specific DTO. Its only Domain dependency is the `AgeCategory` enum from `lib/core/domain/model/profile.dart`.

#### Scenario: ageCategoryToWire maps each enum variant to its snake_case wire string

- **GIVEN** the five `AgeCategory` variants: `bebe`, `enfant`, `ado`, `jeuneAdulte`, `adulte`
- **WHEN** `ageCategoryToWire` is called on each
- **THEN** the returned values are `"bebe"`, `"enfant"`, `"ado"`, `"jeune_adulte"`, `"adulte"` respectively

#### Scenario: ageCategoryFromWire parses each snake_case string to its enum variant

- **GIVEN** the five wire strings: `"bebe"`, `"enfant"`, `"ado"`, `"jeune_adulte"`, `"adulte"`
- **WHEN** `ageCategoryFromWire` is called on each
- **THEN** the returned values are `AgeCategory.bebe`, `AgeCategory.enfant`, `AgeCategory.ado`, `AgeCategory.jeuneAdulte`, `AgeCategory.adulte` respectively

#### Scenario: ageCategoryFromWire throws on unknown value

- **WHEN** `ageCategoryFromWire("teen")` is called
- **THEN** the call throws `FormatException` whose message contains `"Unknown age_category"` and the offending string `"teen"`

#### Scenario: Round-trip is lossless

- **GIVEN** any `AgeCategory` variant
- **WHEN** the value is serialized via `ageCategoryToWire` then parsed back via `ageCategoryFromWire`
- **THEN** the round-tripped value equals the original

---

### Requirement: RemoteMovieDto wire-format DTO

The system SHALL define a wire-format DTO `RemoteMovieDto` in
`lib/core/application/dtos/remote_movie.dto.dart` that mediates between
the JSON payload of a `kind: "movie"` catalog item (from `/catalog` or
`/catalog/search`) and the Domain `Movie` entity.

The wire schema is unchanged from the prior version of this
capability EXCEPT that:

- The wire payload now carries a top-level `kind: "movie"` field
  (added by the `add-series-viewing` server-side change). The DTO
  SHALL **tolerate and ignore** this field — it is not stored on the
  DTO. The DTO knows it represents a Movie by construction (called
  through the dispatch helper `catalogItemFromJson`).

All other fields (`id`, `title`, `original_title`, `year`,
`duration_seconds`, `synopsis`, `tagline`, `poster_url`,
`backdrop_url`, `age_category`, `genres`, `saga_id`, `saga_label`,
`director`, `cast`, `added_at`) and their Domain mapping are preserved
verbatim.

#### Scenario: Tolerates the kind field in input

- **GIVEN** a wire payload that includes `"kind": "movie"` alongside
  the standard fields
- **WHEN** `RemoteMovieDto.fromJson(payload).toDomain()` is called
- **THEN** the call succeeds and the returned `Movie` has every other
  field populated correctly

#### Scenario: Parses without the kind field (backward compatibility)

- **GIVEN** a wire payload without a `kind` field (e.g. for tests or a
  legacy fixture)
- **WHEN** `RemoteMovieDto.fromJson(payload)` is called directly (not
  via the dispatch helper)
- **THEN** the call succeeds (the `kind` field is optional from the
  DTO's perspective)

### Requirement: RemoteCastMemberDto nested wire DTO

The system SHALL define a nested wire DTO `RemoteCastMemberDto` in `lib/core/application/dtos/remote_movie.dto.dart` (same file as `RemoteMovieDto`) that mediates between the JSON `cast[]` entries and the Domain `CastMember` entity.

The DTO SHALL expose:

- `factory RemoteCastMemberDto.fromJson(Map<String, dynamic> json)`
- `CastMember toDomain()`

The wire schema SHALL be:

| Wire field | Wire type | Domain mapping |
|---|---|---|
| `name` | `String` | direct |
| `role` | `String?` | direct |
| `photo_url` | `String?` | direct (maps to `CastMember.photoUrl`) |

#### Scenario: Parses a fully populated cast entry

- **GIVEN** a wire payload `{"name": "Guillaume Canet", "role": "Astérix", "photo_url": "https://..."}`
- **WHEN** parsed and projected to Domain
- **THEN** the returned `CastMember` has `name == "Guillaume Canet"`, `role == "Astérix"`, `photoUrl == "https://..."`

#### Scenario: Parses a cast entry with null role and photo_url

- **GIVEN** a wire payload `{"name": "Hayao Miyazaki", "role": null, "photo_url": null}`
- **WHEN** parsed and projected to Domain
- **THEN** the returned `CastMember` has `name == "Hayao Miyazaki"`, `role == null`, `photoUrl == null`

---

### Requirement: HTTP implementation of CatalogRepository (DioCatalogRepository)

The system SHALL provide an HTTP implementation `DioCatalogRepository
implements CatalogRepository` in
`lib/infrastructure/catalog/dio.catalog.repository.dart` that calls
the backend `/catalog` and `/catalog/search` endpoints documented in
`API.md` § Catalogue.

The class SHALL accept a `Dio` instance via its constructor.
`AuthInterceptor` injects `Authorization`, `X-Device-Id`, and
`X-Profile-Id` transparently for every protected request, including
`/catalog` and `/catalog/search`.

`listCatalog()` SHALL:

1. Issue `GET /catalog` with **no query parameters**.
2. On HTTP 200, parse the response body as `Map<String, dynamic>`,
   read the `items` key as a `List`, cast each element to
   `Map<String, dynamic>`, and project each via `catalogItemFromJson`
   (which dispatches based on `kind`).
3. Return the resulting `List<CatalogItem>` in iteration order
   (no client-side sorting).
4. On any `DioException`, rethrow. No metier-level exception mapping.

`searchCatalog({required String query})` SHALL:

1. Issue `GET /catalog/search` with the single query parameter
   `q=<query>`.
2. The query SHALL be passed verbatim — no client-side trimming,
   lowercasing, or accent normalization.
3. The repository SHALL NOT short-circuit on empty/whitespace-only
   `query` — minimum query length and debouncing remain the UI/controller's
   responsibility.
4. On HTTP 200, parse `response.data['items']` and project via
   `catalogItemFromJson`.
5. Return the resulting `List<CatalogItem>` in iteration order
   (sorting is the application service's responsibility).
6. On any `DioException`, rethrow.

The implementation SHALL NOT log raw response bodies or any header
value at any log level.

#### Scenario: listCatalog sends GET /catalog without query params and parses items envelope

- **GIVEN** the backend responds 200 with body `{"items": [<movie1>,
  <series1>]}` for `GET /catalog`
- **WHEN** `listCatalog()` is called
- **THEN** the request method is `GET` on path `/catalog` (NOT `/movies`)
- **AND** the request has no query parameters
- **AND** the future completes with a `List<CatalogItem>` of length 2

#### Scenario: searchCatalog sends GET /catalog/search?q=...

- **GIVEN** the backend responds 200 with `{"items": [<movie1>]}`
  for `GET /catalog/search?q=astérix`
- **WHEN** `searchCatalog(query: "astérix")` is called
- **THEN** the request method is `GET` on path `/catalog/search` (NOT
  `/movies/search`)
- **AND** the request has query parameter `q == "astérix"` (raw)
- **AND** the future completes with a `List<CatalogItem>` of length 1

#### Scenario: rethrows on 401 invalid_token

- **GIVEN** the backend responds 401 with body `{"error": {"code":
  "invalid_token"}}` on either method
- **THEN** the future throws `DioException` with `statusCode == 401`

#### Scenario: rethrows on 5xx

- **GIVEN** the backend responds 500 on either method
- **THEN** the future throws `DioException` with `statusCode == 500`

#### Scenario: throws on unknown kind in items array

- **GIVEN** the backend responds 200 with `{"items": [{"kind":
  "podcast", ...}]}`
- **WHEN** `listCatalog()` is called
- **THEN** the future throws `FormatException` (propagated from
  `catalogItemFromJson`) — fail-fast on backend contract violation

---

### Requirement: CatalogRepository implementation selection via API_BASE_URL

The system SHALL select between the in-memory and HTTP implementations of `CatalogRepository` based on the compile-time constant `String.fromEnvironment('API_BASE_URL')`, mirroring the selection logic for `AuthRepository` and `ProfileManagementRepository`.

The selection logic SHALL live in the Riverpod provider `catalogRepositoryProvider` (`lib/infrastructure/providers/catalog.repository_provider.dart`) and SHALL behave as follows:

```dart
const baseUrl = String.fromEnvironment('API_BASE_URL');
if (baseUrl.isEmpty) {
  return InMemoryCatalogRepository();  // existing behavior
}
return DioCatalogRepository(ref.watch(dioProvider));  // new behavior
```

The selection SHALL happen at build time via the `--dart-define` mechanism — `String.fromEnvironment` is a `const` expression evaluated at compilation, NOT a runtime lookup of an environment variable.

When `API_BASE_URL` is unset (default), the provider SHALL return the existing `InMemoryCatalogRepository` so that:

- Developers running `flutter run` without the flag get the in-memory behavior identical to before this change.
- Tests running `flutter test` (which never pass `--dart-define`) continue to use the in-memory implementation.

When `API_BASE_URL` is set to a non-empty string, the provider SHALL return a `DioCatalogRepository` consuming the centralized `dioProvider`.

The provider SHALL remain `@Riverpod(keepAlive: true)` so the chosen implementation is created once per app lifetime.

The selection SHALL be consistent with `authRepositoryProvider` and `profileManagementRepositoryProvider`: a build either runs all repositories in in-memory mode (no flag) or all in HTTP mode (flag set). Mixed modes are not supported and SHALL not be exposed.

#### Scenario: Default build returns InMemoryCatalogRepository

- **GIVEN** the app is built without `--dart-define=API_BASE_URL`
- **WHEN** any consumer reads `catalogRepositoryProvider`
- **THEN** the returned instance is of runtime type `InMemoryCatalogRepository`

#### Scenario: Build with API_BASE_URL returns DioCatalogRepository

- **GIVEN** the app is built with `--dart-define=API_BASE_URL=http://localhost:8080`
- **WHEN** any consumer reads `catalogRepositoryProvider`
- **THEN** the returned instance is of runtime type `DioCatalogRepository`

#### Scenario: Test override remains supported

- **GIVEN** a test that overrides `catalogRepositoryProvider` with a fake implementation via `ProviderContainer.test`
- **WHEN** the consumer reads `catalogRepositoryProvider` in the test
- **THEN** the fake is returned regardless of the `API_BASE_URL` value the test was compiled with

### Requirement: Sealed CatalogItem hierarchy

The system SHALL define a `sealed class CatalogItem` in
`lib/core/domain/model/media.dart` with the following abstract getters,
which represent the fields common to every catalog tile shown on the
homepage:

- `String get id`
- `String get title`
- `String? get originalTitle`
- `int? get year`
- `String get synopsis`
- `String? get tagline`
- `String? get posterUrl`
- `String? get backdropUrl`
- `AgeCategory get ageCategory`
- `List<String> get genres`
- `String? get sagaId`
- `String? get sagaLabel`
- `List<String> get director`
- `List<CastMember> get cast`
- `DateTime get addedAt`

The sealed hierarchy SHALL contain exactly two variants:
- `Movie` (defined in this capability) — `extends CatalogItem` and
  `implements PlayableMedia` (the latter is defined in the
  `series-viewing` capability).
- `Series` (defined in the `series-viewing` capability) —
  `extends CatalogItem` only.

Any switch over `CatalogItem` SHALL be exhaustive at compile-time
without a `default` branch.

#### Scenario: Exhaustive switch over CatalogItem

- **GIVEN** a function that switches on `CatalogItem`
- **WHEN** the function omits a branch for `Movie` or `Series`
- **THEN** the Dart analyzer emits a non-exhaustive switch error

#### Scenario: Movie satisfies CatalogItem getters

- **GIVEN** a `Movie` with `title == "Nemo"` and `addedAt == 2026-04-01`
- **WHEN** treated as `CatalogItem`
- **THEN** `item.title == "Nemo"` and `item.addedAt == 2026-04-01`

#### Scenario: Series satisfies CatalogItem getters

- **GIVEN** a `Series` with `title == "Pingu"` and `addedAt == 2026-05-04`
- **WHEN** treated as `CatalogItem`
- **THEN** `item.title == "Pingu"` and `item.addedAt == 2026-05-04`

---

### Requirement: catalogItemFromJson dispatch helper

The system SHALL define a top-level function `catalogItemFromJson` in
`lib/core/application/dtos/remote_catalog_item.dto.dart` that parses a
single catalog item wire payload from the `/catalog` and
`/catalog/search` responses:

```dart
CatalogItem catalogItemFromJson(Map<String, dynamic> json);
```

The function SHALL switch on `json['kind']`:

- `"movie"` → `RemoteMovieDto.fromJson(json).toDomain()`
- `"series"` → `RemoteSeriesCatalogDto.fromJson(json).toDomain()` (DTO
  defined in the `series-viewing` capability)
- any other value (including missing key) → throws `FormatException`
  whose message contains `"Unknown catalog kind"` and the offending
  value.

The function SHALL NOT silently coerce a missing or null `kind` — that
indicates a backend contract bug and SHALL fail fast.

#### Scenario: Dispatches movie payload to RemoteMovieDto

- **GIVEN** a wire payload `{"kind": "movie", "id": "nemo", ...}`
- **WHEN** `catalogItemFromJson(payload)` is called
- **THEN** the result is a `Movie` whose `id == "nemo"`

#### Scenario: Dispatches series payload to RemoteSeriesCatalogDto

- **GIVEN** a wire payload `{"kind": "series", "id": "pingu",
  "seasons_count": 6, ...}`
- **WHEN** `catalogItemFromJson(payload)` is called
- **THEN** the result is a `Series` whose `id == "pingu"` and
  `seasonsCount == 6`

#### Scenario: Throws on unknown kind

- **GIVEN** a wire payload `{"kind": "podcast", "id": "x", ...}`
- **WHEN** `catalogItemFromJson(payload)` is called
- **THEN** the call throws `FormatException` whose message contains
  `"Unknown catalog kind"` and `"podcast"`

#### Scenario: Throws on missing kind

- **GIVEN** a wire payload `{"id": "nemo", ...}` without a `kind` key
- **WHEN** `catalogItemFromJson(payload)` is called
- **THEN** the call throws `FormatException`

---

### Requirement: CatalogRepository.listCatalogForProfile

The system SHALL extend `CatalogRepository` with a profile-explicit
listing method:

```dart
Future<List<CatalogItem>> listCatalogForProfile(String profileId);
```

The method SHALL return the catalog items visible to the profile
identified by [profileId], regardless of which profile is currently
active in the session.

The method exists because `/catalog` returns ONLY items whose
`age_category` equals the active profile's exactly (per `API.md` §
Catalogue, not hierarchical). The downloads manager needs to surface
items downloaded by ANY family profile — querying the catalog once
per profile and unioning the results bridges that gap without backend
changes.

* The HTTP implementation SHALL issue `GET /catalog` with
  `X-Profile-Id: $profileId` pre-set on the per-call `Options.headers`.
  The `AuthInterceptor` SHALL preserve such an explicit override (see
  `kids-lock` / `auth` capability for that interceptor change).
* The in-memory implementation SHALL return the same content as
  `listCatalog()` (no profile filter at this layer).

#### Scenario: HTTP impl uses the per-call profile header

- **GIVEN** `currentProfileId` resolves to `"parent"` and the session contains a kid profile `"marie"`
- **WHEN** `listCatalogForProfile("marie")` is called
- **THEN** the outbound `GET /catalog` carries `X-Profile-Id: marie` (NOT `parent`)
- **AND** the response is parsed into the returned `List<CatalogItem>`

#### Scenario: In-memory impl ignores the profile id

- **GIVEN** the in-memory repo is in use
- **WHEN** `listCatalogForProfile("any-id")` is called
- **THEN** the result is identical to `listCatalog()`

---

### Requirement: AuthInterceptor preserves a per-call X-Profile-Id override

The system SHALL configure the `AuthInterceptor`
(`lib/infrastructure/http/auth.interceptor.dart`) to forward an
`X-Profile-Id` header that is already present on the outbound
request's `RequestOptions.headers` instead of overwriting it from
`currentProfileIdProvider`.

The behavior is unchanged when no `X-Profile-Id` header is set on the
per-call options — the interceptor still injects the active profile
id from the callback.

This carve-out enables `CatalogRepository.listCatalogForProfile` and
`SeriesRepository.findByIdForProfile` to address the backend on
behalf of an arbitrary family profile without rebuilding `Dio`.

#### Scenario: Interceptor preserves the explicit header

- **GIVEN** a `Dio` request whose `options.headers` already contains `'X-Profile-Id': 'marie'`
- **WHEN** the `AuthInterceptor.onRequest` callback fires
- **THEN** the outgoing request carries `X-Profile-Id: marie`
- **AND** the value is NOT replaced by `_currentProfileId()`

#### Scenario: Interceptor still injects when header is absent

- **GIVEN** a `Dio` request whose `options.headers` does NOT contain `X-Profile-Id`
- **AND** `_currentProfileId()` returns `"parent"`
- **WHEN** the interceptor fires
- **THEN** the outgoing request carries `X-Profile-Id: parent`

---

### Requirement: Movie detail modal exposes a Télécharger action

The system SHALL extend the movie detail modal (cf. requirement *Movie
detail modal is adaptive and presents full metadata*) to expose,
immediately to the right of the existing primary `[Lire]` button, a
secondary button whose label and behavior depend on the current `kind`
of the download for this movie:

| Current state | Button label | Tap behavior |
|---|---|---|
| No file on disk OR `kind == cache` | `[⬇ Télécharger]` | Triggers parent PIN gate (cf. *Download actions are gated by parent PIN when active profile is kid*), then `MarkAsDownloadUseCase.execute(mediaId, isEpisode: false)`. If no download is in flight, ALSO subscribes to `downloadMovie(id)` to start the actual transfer. |
| `kind == download`, file on disk | `[✓ Téléchargé]` (visually muted) | Opens a bottom sheet with `[Ne plus garder]` (calls `MarkAsCacheUseCase`) and `[Supprimer]` (calls `deleteMovie` after confirmation). Both options behind the PIN gate. |
| In-flight, not yet `complete` | `[⏸ X %]` (where X is `bytesReceived / bytesTotal`) | No tap action (or shows a tooltip "Téléchargement en cours"). |

The button SHALL reflect the current state reactively: a `Stream` /
`Future` consumer that observes `findForMovie(id)` (and `kind` via
the manifest) and rebuilds.

The button SHALL NOT replace or hide the `[Lire]` button. Both
remain visible side by side.

#### Scenario: Movie not yet downloaded shows Télécharger

- **GIVEN** the modal is open for a movie with no file on disk
- **THEN** the secondary button reads `[⬇ Télécharger]`

#### Scenario: Movie already downloaded shows Téléchargé

- **GIVEN** the modal is open for a movie whose manifest has `kind == download`
- **THEN** the secondary button reads `[✓ Téléchargé]`

#### Scenario: Tap on Télécharger triggers PIN gate then promotion

- **GIVEN** the active profile is a kid
- **AND** the modal is open for a movie not yet downloaded
- **WHEN** the user taps `[⬇ Télécharger]`
- **THEN** the parent PIN dialog appears
- **AND** on success, `MarkAsDownloadUseCase.execute` is invoked
- **AND** the actual download stream starts via `downloadMovie(id)` if not already in flight

#### Scenario: Mid-flight Télécharger flips manifest without restart

- **GIVEN** the modal is open and the movie is being downloaded as cache (player started it 30 s ago)
- **WHEN** the parent confirms the PIN and `MarkAsDownloadUseCase` runs
- **THEN** the manifest entry's `kind` becomes `download`
- **AND** the in-flight download continues without restart or interruption

---

### Requirement: Episode card and season section expose download actions

The system SHALL extend the series detail modal so that each episode
card (`episode_card.dart`) exposes a download icon affordance to the
right of the existing card content (title, duration, etc.):

| Current state | Icon | Tap behavior |
|---|---|---|
| No file OR `kind == cache` | `Icons.file_download_outlined` | PIN gate, then promote/start (`MarkAsDownloadUseCase` for the episode + subscribe to `downloadEpisode` if not in flight). |
| `kind == download` on disk | `Icons.file_download_done` | Opens action sheet `[Ne plus garder] / [Supprimer]`. |
| In flight | `Icons.file_download` with circular progress overlay (X %) | No tap. |

In the series detail modal, each season section
(`season_section.dart`) SHALL expose a header-level button
`[⬇ Télécharger la saison]` to the right of the season title. Its
behavior:

- If at least one episode of the season is **not** in `kind ==
  download` state (cache, in-flight, or absent), the button is
  enabled. Tapping it triggers the PIN gate, then
  `DownloadSeasonUseCase.execute(seriesId, seasonNumber)`. The button
  shows live progress (`"X / N épisodes"`) while the use case stream
  emits.
- If all episodes are already `kind == download`, the button reads
  `[✓ Saison téléchargée]` and is disabled (or transforms into a
  shortcut to delete the whole season — TBD, deferred).

The season-level button SHALL trigger the **single PIN gate** for
the whole season (one challenge, then all episodes). Per-episode
icon taps trigger their own gate.

The season-level button SHALL show a Snackbar
`"Saison Pingu — N épisodes téléchargés"` on completion.

If the user cancels the season download mid-flight (back button,
explicit cancel affordance — to be specified at impl time), the
in-flight episode download is cancelled (via `cancelEpisode`) and
the loop stops. Already-downloaded episodes remain `kind ==
download`.

#### Scenario: Episode icon shows Télécharger when absent

- **GIVEN** the series modal lists episode `pingu-s01e04` not yet on disk
- **THEN** the icon affordance is `Icons.file_download_outlined`

#### Scenario: Episode icon shows Done when downloaded

- **GIVEN** episode `pingu-s01e04` has manifest `kind == download`
- **THEN** the icon affordance is `Icons.file_download_done`

#### Scenario: Saison button uses single PIN gate

- **GIVEN** the active profile is a kid
- **AND** Season 1 has 8 episodes, none yet downloaded
- **WHEN** the user taps `[⬇ Télécharger la saison]`
- **THEN** the parent PIN dialog appears exactly once
- **AND** on success, episodes are downloaded sequentially without further PIN prompts
- **AND** each completed episode is automatically marked `kind == download`

#### Scenario: Saison button shows progress and Snackbar

- **GIVEN** Season 1 download starts, 5 episodes
- **WHEN** episode 3 completes
- **THEN** the season button label updates to `"Saison Pingu — 3 / 5 épisodes"`
- **WHEN** episode 5 completes (last)
- **THEN** the button transitions to `[✓ Saison téléchargée]`
- **AND** a Snackbar `"Saison Pingu — 5 épisodes téléchargés"` is displayed

#### Scenario: Saison cancellation stops loop, preserves done episodes

- **GIVEN** Season 1 download is at episode 3 of 8
- **AND** episodes 1 and 2 are already complete + marked `download`
- **WHEN** the user dismisses / cancels the season download
- **THEN** episode 3's in-flight download is cancelled (`cancelEpisode`)
- **AND** episodes 4–8 are NOT attempted
- **AND** episodes 1 and 2 remain `kind == download` on disk

---

### Requirement: Download actions are gated by parent PIN when active profile is kid

The system SHALL gate every action that mutates a download's `kind` to
`DownloadKind.download` or that initiates a `Télécharger la saison`
flow: when the active profile is **not** the main profile (parent),
the action MUST trigger the PIN challenge defined by the existing
`kids-lock` capability (requirement *Tapping the unlock button opens
a PIN dialog*).

The same dialog widget (`showUnlockPinDialog` or its sibling for
out-of-player contexts — implementation choice) SHALL be reused.
Implementations SHALL NOT define a parallel PIN dialog.

The challenge SHALL be invoked **before** the use case runs. On a
cancelled or invalid PIN, the use case SHALL NOT be called and the
UI state SHALL remain unchanged.

When the active profile **is** the main profile (parent), the
challenge SHALL be skipped and the use case SHALL run directly.

The PIN challenge SHALL also gate:

- The **Supprimer** action on a download (`deleteMovie/Episode`) —
  destructive, parent's authority.
- The **Ne plus garder** action (`MarkAsCacheUseCase`) — exposes
  the item to auto-cleanup, parent's authority.
- Navigation to the **Downloads page** (`/downloads`) — see the
  separate `download-management` requirement on this point.

The PIN challenge SHALL NOT gate:

- The implicit playback flow (pressing `[Lire]` on a movie or
  episode) — playback already triggers a `cache` download which
  remains under auto-cleanup, no parent intent needed.
- The `[Lire]` button on a tile in the Downloads page (the parent
  is already past the page-level gate).

#### Scenario: Kid profile cannot bypass the gate

- **GIVEN** the active profile is a kid
- **AND** the kid taps `[⬇ Télécharger]`
- **AND** the parent declines or wrong-PINs the dialog
- **THEN** `MarkAsDownloadUseCase` is NOT called
- **AND** the manifest is unchanged

#### Scenario: Parent profile skips the gate

- **GIVEN** the active profile is the main profile
- **AND** the parent taps `[⬇ Télécharger]`
- **THEN** the PIN dialog does NOT appear
- **AND** `MarkAsDownloadUseCase` is invoked directly

#### Scenario: Implicit cache download is not gated

- **GIVEN** the active profile is a kid
- **AND** the kid taps `[▶ Lire]` on a movie
- **THEN** the player opens normally and the underlying `downloadMovie` stream starts
- **AND** the PIN dialog does NOT appear
- **AND** the new manifest entry has `kind == cache` (no parent intent)

