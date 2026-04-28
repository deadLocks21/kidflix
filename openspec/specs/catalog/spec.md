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

The system SHALL represent a movie as an immutable Domain entity `Movie` with
the following fields:

- `id`: stable identifier (string) — derived from the external source (e.g.
  IMDb or TMDB id).
- `title`: display title (non-empty string).
- `originalTitle`: original title (nullable string, same as `title` when
  absent).
- `year`: release year (integer, nullable if unknown).
- `duration`: total runtime as a `Duration`.
- `synopsis`: long-form plot description (string, may be empty).
- `tagline`: short marketing line (nullable string).
- `posterUrl`: URL of the poster artwork (nullable string; when null, the UI
  displays a fallback placeholder).
- `backdropUrl`: URL of the fanart / backdrop used in the detail modal
  (nullable string).
- `ageCategory`: `AgeCategory` enum value — REUSES the enum defined by the
  `profile-selection` capability (`bebe`, `enfant`, `ado`, `jeuneAdulte`,
  `adulte`).
- `genres`: ordered `List<String>` — the first entry is the "primary genre"
  used for row grouping.
- `sagaId`: stable identifier of the saga the movie belongs to (nullable
  string). When non-null, `sagaLabel` SHALL also be non-null.
- `sagaLabel`: display name of the saga (nullable string).
- `director`: `List<String>` of director names (possibly empty).
- `cast`: ordered `List<CastMember>` — order reflects billing from the
  source metadata (tinyMediaManager NFO ordering).
- `addedAt`: `DateTime` when the movie entered the catalog (used to compute
  the "Récemment ajoutés" row).

A `CastMember` SHALL contain `name` (string), `role` (nullable string), and
`photoUrl` (nullable string).

The entity SHALL be equatable by `id`.

#### Scenario: Movie without saga

- **WHEN** a `Movie` is constructed with `sagaId = null` and `sagaLabel = null`
- **THEN** it is accepted and considered standalone for row composition

#### Scenario: Movie with saga

- **WHEN** a `Movie` is constructed with `sagaId = "asterix"` and `sagaLabel = "Astérix"`
- **THEN** it is considered a member of the `"asterix"` saga for row composition

#### Scenario: Primary genre is the first in the list

- **GIVEN** a `Movie` with `genres = ["Familial", "Comédie", "Aventure"]`
- **THEN** its primary genre is `"Familial"`

---

### Requirement: CatalogRow and CatalogRowType model

The system SHALL represent a row as an immutable data class `CatalogRow` with
the following fields:

- `label`: display label shown above the row (non-empty string).
- `type`: `CatalogRowType` enum value.
- `movies`: ordered `List<Movie>` — may be empty.

The `CatalogRowType` enum SHALL contain exactly the following variants:

- `continueWatching`
- `recentlyAdded`
- `favorites`
- `saga`
- `genre`
- `neverWatched`
- `downloaded`

For rows of type `saga` and `genre`, multiple `CatalogRow` instances can be
emitted by the application service (one per distinct saga and per distinct
genre present in the catalog). For all other types, at most one `CatalogRow`
instance SHALL be emitted.

#### Scenario: CatalogRow can be empty

- **WHEN** a `CatalogRow` is constructed with `movies = []`
- **THEN** it is a valid instance
- **AND** the UI layer is responsible for hiding it (see empty-row requirement)

---

### Requirement: Catalog repository returns raw movies per age category

The system SHALL define a Domain interface `CatalogRepository`. For
homepage composition, it exposes:

```dart
Future<List<Movie>> listMoviesFor();
```

The repository SHALL return all movies the active profile is allowed to
see. The repository itself SHALL NOT know which profile is active —
the filter is applied **outside the repository**:

- In the HTTP implementation (`DioCatalogRepository`), the backend
  filters server-side based on the `X-Profile-Id` header injected by
  the `AuthInterceptor`. The repository sends `GET /movies` with no
  query parameters; the backend resolves the active profile and returns
  only movies whose `ageCategory == profile.ageCategory`.
- In the in-memory implementation (`InMemoryCatalogRepository`), no
  filter is applied at all — the repository returns the full seeded
  list. In-memory mode is for dev/test of the chain
  UI/usecase/service ; profile-scoped age filtering is validated by
  the HTTP integration tests and the backend's own test suite, not by
  the in-memory repo.

The repository SHALL NOT know about rows, grouping, or the active
profile. The signature `listMoviesFor()` (no parameter) is the wire
guarantee that the repository has no profile-awareness.

In this change, the in-memory implementation SHALL continue to seed at
least 10 fictional movies distributed across all five age categories,
with at least:

- One saga of ≥ 2 movies (so the saga row can be exercised).
- Movies from at least 3 different primary genres in the `enfant`
  category.
- At least one movie in each age category.

The seed is unchanged from prior versions ; only the *return* of
`listMoviesFor()` is no longer filtered.

#### Scenario: In-memory repository returns the full seed regardless of any active profile

- **GIVEN** an `InMemoryCatalogRepository` containing movies across all age categories
- **WHEN** `listMoviesFor()` is called
- **THEN** the returned list contains every seeded movie
- **AND** no movie is filtered out based on age category at the repository layer

#### Scenario: HTTP repository sends GET /movies with no query parameters

- **GIVEN** a `DioCatalogRepository` whose `Dio` has `baseUrl == "http://test.local"`
- **AND** the backend responds 200 with `{"movies": [<movie1>, <movie2>]}`
- **WHEN** `listMoviesFor()` is called
- **THEN** the request method is `GET` on path `/movies`
- **AND** the request has no query parameter `age_category`
- **AND** the request has no query parameter at all (the path is `/movies` exactly)
- **AND** the future completes with a `List<Movie>` of length 2 whose elements match the parsed `<movie1>` and `<movie2>`

---

### Requirement: Homepage catalog is composed by an application service

The system SHALL expose an Application-layer service
`CatalogApplicationService` with a method:

```dart
Future<List<CatalogRowDto>> buildHomeRowsFor(ProfileDto profile);
```

The service SHALL:

1. Call `CatalogRepository.listMoviesFor()` to get the raw movies
   available to the **active** profile (filtering is the repository
   implementation's responsibility — server-side in HTTP mode, no-op
   in in-memory mode).
2. Assemble a list of `CatalogRow` instances following the row
   composition rules (see subsequent requirements).
3. Apply the fixed row ordering (see row-ordering requirement).
4. Convert each `CatalogRow` into a `CatalogRowDto` (containing
   `List<MovieDto>` instead of `List<Movie>`).
5. Return only rows with at least one movie (empty rows are filtered
   out).

The service SHALL NOT pass `profile.ageCategory` (or any age value)
to the repository. The `ProfileDto` parameter is preserved on the
method signature because future row-composition decisions may consume
profile metadata other than the age category (e.g. row labels, badge
display), but the parameter is no longer used as an age filter.

The service SHALL expose its behavior through a Riverpod provider
configured under `lib/infrastructure/providers/` per project
convention.

A usecase `ListHomeCatalogUseCase` SHALL wrap the service call,
accepting a `ProfileDto` and returning `Future<List<CatalogRowDto>>`.
The homepage consumes the usecase via its Riverpod provider.

#### Scenario: Service returns only non-empty rows

- **GIVEN** a profile with no `favorites`, no `continueWatching`, and no catalog movies
- **WHEN** `buildHomeRowsFor(profile)` is called
- **THEN** the returned list is empty

#### Scenario: Service does not expose Domain entities to the UI

- **WHEN** the service returns rows
- **THEN** each row contains `MovieDto` objects (not `Movie`)
- **AND** no `Movie` Domain entity crosses the Application/UI boundary

#### Scenario: Service does not pass ageCategory to the repository

- **GIVEN** a profile with `ageCategory == AgeCategory.enfant`
- **WHEN** `buildHomeRowsFor(profile)` is called
- **THEN** `CatalogRepository.listMoviesFor()` is called with no argument (the new signature has no parameter)
- **AND** the service does not inspect or forward `profile.ageCategory` to the repository

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
Future<List<Movie>> searchMovies({required String query});
```

The method SHALL return every movie whose normalized `title` OR
normalized `originalTitle` (when non-null) contains the normalized
`query` as a substring, where normalization is case-insensitive and
accent-insensitive (see the `search` capability for the exact rules).
The age-hierarchy filter (`movie.ageCategory ≤ active profile age
category`) is applied **outside the repository**:

- In the HTTP implementation (`DioCatalogRepository`), the backend
  filters server-side based on the `X-Profile-Id` header. The
  repository sends `GET /movies/search?q=<query>` with only the `q`
  query parameter — the backend resolves the active profile and applies
  the hierarchical scope.
- In the in-memory implementation (`InMemoryCatalogRepository`), no
  age filter is applied. The repository returns every seeded movie
  whose normalized title matches the normalized query, regardless of
  age category. In-memory tests SHALL adjust their fixtures or
  assertions accordingly.

The method SHALL NOT know about rows, the active profile, sorting, or
debouncing. Sorting the results is the responsibility of the
`SearchApplicationService`. Debouncing and minimum-query-length
enforcement are responsibilities of the UI/controller layer.

The HTTP implementation maps this method to the single backend endpoint
`GET /movies/search?q={query}`, preserving the 1:1 signature. The HTTP
implementation does not normalize the query client-side — it forwards
the raw string and the backend applies normalization symmetrically on
both query and titles.

#### Scenario: In-memory repository returns matches across all categories

- **GIVEN** an `InMemoryCatalogRepository` containing a `bebe` movie "Shaun", an `enfant` movie "Totoro", and a `jeuneAdulte` movie "Inception", all matching the query "o"
- **WHEN** `searchMovies(query: "o")` is called
- **THEN** the returned list contains Shaun, Totoro and Inception
- **AND** no age-hierarchy filter is applied at the in-memory repository layer

#### Scenario: Repository applies normalized substring matching

- **GIVEN** a repository containing a movie with `title = "Astérix"`
- **WHEN** `searchMovies(query: "asterix")` is called
- **THEN** the movie is present in the returned list

#### Scenario: Repository does not sort

- **WHEN** `searchMovies(query: "o")` is called
- **THEN** the returned list order is implementation-defined (natural iteration)
- **AND** sorting is applied by the application service, not by the repository

#### Scenario: HTTP repository sends only the q query parameter

- **GIVEN** a `DioCatalogRepository` whose `Dio` has `baseUrl == "http://test.local"`
- **AND** the backend responds 200 with `{"movies": []}`
- **WHEN** `searchMovies(query: "astérix")` is called
- **THEN** the request method is `GET` on path `/movies/search`
- **AND** the request has query parameter `q == "astérix"` (raw, accents preserved)
- **AND** the request has NO query parameter `up_to_age_category`

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

The system SHALL define a wire-format DTO `RemoteMovieDto` in `lib/core/application/dtos/remote_movie.dto.dart` that mediates between the JSON payload returned by the backend `/movies` endpoints and the Domain `Movie` entity.

The DTO SHALL expose:

- `factory RemoteMovieDto.fromJson(Map<String, dynamic> json)` — parses a single movie wire payload.
- `Movie toDomain()` — projects the DTO to its Domain entity.

The DTO SHALL NOT expose `toJson()` — the client does not push movies to the backend in any current or planned flow.

The wire schema SHALL be parsed as follows:

| Wire field | Wire type | DTO field | Domain mapping |
|---|---|---|---|
| `id` | `String` | `id` | direct |
| `title` | `String` | `title` | direct |
| `original_title` | `String?` | `originalTitle` | direct |
| `year` | `int?` | `year` | direct |
| `duration_seconds` | `int` | `durationSeconds` | `Duration(seconds: ...)` in `toDomain` |
| `synopsis` | `String` | `synopsis` | direct |
| `tagline` | `String?` | `tagline` | direct |
| `poster_url` | `String?` | `posterUrl` | direct |
| `backdrop_url` | `String?` | `backdropUrl` | direct |
| `age_category` | `String` | `ageCategory: AgeCategory` | `ageCategoryFromWire(...)` in `fromJson` |
| `genres` | `List<String>` | `genres` | direct |
| `saga_id` | `String?` | `sagaId` | direct |
| `saga_label` | `String?` | `sagaLabel` | direct |
| `director` | `List<String>` | `director` | direct |
| `cast` | `List<Map>` | `cast: List<RemoteCastMemberDto>` | each via `RemoteCastMemberDto.fromJson` |
| `added_at` | `String` (ISO 8601) | `addedAt: DateTime` | `DateTime.parse(...)` in `fromJson` |

The `cast` list SHALL be parsed via a nested `RemoteCastMemberDto` (see next requirement).

`fromJson` SHALL parse the wire `int` for `duration_seconds` directly into an `int` field on the DTO; the conversion to `Duration` happens in `toDomain`. This preserves the convention that `fromJson` describes the post-JSON-parse Dart primitive shape, and `toDomain` performs the wire-to-Domain projection.

`fromJson` SHALL parse `added_at` directly into a `DateTime` (via `DateTime.parse`), since the wire format is unambiguous and there is no additional projection step needed.

`fromJson` SHALL NOT silently coerce missing required fields (`id`, `title`, `synopsis`, `duration_seconds`, `age_category`, `genres`, `director`, `cast`, `added_at`). A missing required field SHALL surface as a runtime cast/null error during parsing.

#### Scenario: Parses a complete movie payload

- **GIVEN** a wire payload with all fields populated (matching the example in `API.md` § Catalogue)
- **WHEN** `RemoteMovieDto.fromJson(payload).toDomain()` is called
- **THEN** the returned `Movie` has every field populated to match the wire payload
- **AND** `Movie.duration` equals `Duration(seconds: payload['duration_seconds'])`
- **AND** `Movie.ageCategory` equals the variant returned by `ageCategoryFromWire(payload['age_category'])`
- **AND** `Movie.addedAt` equals `DateTime.parse(payload['added_at'])`

#### Scenario: Parses a payload with all nullable fields absent

- **GIVEN** a wire payload where `original_title`, `year`, `tagline`, `poster_url`, `backdrop_url`, `saga_id`, `saga_label` are all `null`
- **WHEN** `RemoteMovieDto.fromJson(payload).toDomain()` is called
- **THEN** the returned `Movie` has all those fields equal to `null`
- **AND** required fields parse normally

#### Scenario: Parses an empty cast list

- **GIVEN** a wire payload with `cast: []`
- **WHEN** parsed and projected to Domain
- **THEN** the `Movie.cast` is an empty list

#### Scenario: Round-trips ageCategory through the shared helper

- **GIVEN** a wire payload with `age_category: "jeune_adulte"`
- **WHEN** parsed
- **THEN** `RemoteMovieDto.ageCategory` equals `AgeCategory.jeuneAdulte`

#### Scenario: Throws on unknown age_category wire value

- **GIVEN** a wire payload with `age_category: "teen"`
- **WHEN** `RemoteMovieDto.fromJson(payload)` is called
- **THEN** the call throws `FormatException` (propagated from `ageCategoryFromWire`)

---

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

The system SHALL provide an HTTP implementation `DioCatalogRepository implements CatalogRepository` in `lib/infrastructure/catalog/dio.catalog.repository.dart` that calls the backend `/movies` endpoints documented in `API.md` § Catalogue.

The class SHALL accept a `Dio` instance via its constructor and SHALL NOT instantiate its own — the `Dio` is provided by `dioProvider`, which has the `AuthInterceptor` registered. The repository itself SHALL NOT add `Authorization`, `X-Device-Id`, or `X-Profile-Id` headers explicitly — these are injected transparently by the interceptor since `/movies` does not start with `/auth/` and is not the `GET /profiles` bootstrap exemption.

`listMoviesFor()` SHALL:

1. Issue `GET /movies` with **no query parameters**. The backend resolves the filter from the `X-Profile-Id` header injected by the `AuthInterceptor`.
2. On HTTP 200, parse the response body as `Map<String, dynamic>`, read the `movies` key as a `List`, cast each element to `Map<String, dynamic>`, and project each via `RemoteMovieDto.fromJson(...).toDomain()`.
3. Return the resulting `List<Movie>` in iteration order (no client-side sorting).
4. On any `DioException`, rethrow. No metier-level exception mapping — the contract has no documented business error code on this endpoint beyond `400 missing_profile_id` (which the client surfaces generically since the interceptor is responsible for injecting the header).

`searchMovies({required String query})` SHALL:

1. Issue `GET /movies/search` with the single query parameter `q=<query>`.
2. The `query` SHALL be passed through verbatim — no client-side trimming, lowercasing, or accent normalization. Normalization is applied symmetrically by the backend on both query and titles.
3. The repository SHALL NOT short-circuit on empty/whitespace-only `query` — minimum query length and debouncing are the UI/controller's responsibility per the Domain interface contract.
4. On HTTP 200, parse the response body using the same `{ movies: [...] }` envelope unwrap as `listMoviesFor`.
5. Return the resulting `List<Movie>` in iteration order (no client-side sorting — sorting is the application service's responsibility).
6. On any `DioException`, rethrow. No metier-level exception mapping.

The implementation SHALL NOT log raw response bodies, the `Authorization` header, the JWT, or the `X-Profile-Id` value at any log level.

The implementation SHALL NOT retry failed requests — retry policy is out of scope for this change.

The repository SHALL NOT serialize an `AgeCategory` enum value into any outbound query parameter — there is no longer any age value travelling client-side. The shared helper `ageCategoryToWire` continues to exist for `RemoteProfileDto` and `RemoteMovieDto` (which parse age categories from inbound JSON), but `DioCatalogRepository` no longer consumes it.

#### Scenario: listMoviesFor sends GET /movies without query params and parses the envelope

- **GIVEN** the backend responds 200 with body `{"movies": [<movie1>, <movie2>]}` for `GET /movies`
- **WHEN** `listMoviesFor()` is called
- **THEN** the request method is `GET` on path `/movies`
- **AND** the request has no query parameters
- **AND** the future completes with a `List<Movie>` of length 2 whose elements match the parsed `<movie1>` and `<movie2>`

#### Scenario: listMoviesFor preserves backend order

- **GIVEN** the backend responds 200 with `movies` in order `[m_z, m_a, m_m]`
- **WHEN** `listMoviesFor()` is called
- **THEN** the returned `List<Movie>` is in the same order `[m_z, m_a, m_m]` (the repository does not sort)

#### Scenario: listMoviesFor returns empty list when backend has none

- **GIVEN** the backend responds 200 with `{"movies": []}`
- **WHEN** `listMoviesFor()` is called
- **THEN** the future completes with an empty `List<Movie>`

#### Scenario: searchMovies sends only the q query param

- **GIVEN** the backend responds 200 with `{"movies": [<movie1>]}` for `GET /movies/search?q=astérix`
- **WHEN** `searchMovies(query: "astérix")` is called
- **THEN** the request method is `GET` on path `/movies/search`
- **AND** the request has query parameter `q == "astérix"` (raw, accents preserved)
- **AND** the request has NO query parameter `up_to_age_category`
- **AND** the future completes with a `List<Movie>` of length 1

#### Scenario: searchMovies passes empty query verbatim without bail-out

- **GIVEN** the backend responds 200 with `{"movies": []}` for `GET /movies/search?q=`
- **WHEN** `searchMovies(query: "")` is called
- **THEN** the request is sent to the backend with `q` parameter equal to the empty string
- **AND** the future completes with an empty `List<Movie>`

#### Scenario: searchMovies does not normalize the query client-side

- **GIVEN** the backend responds 200 with `{"movies": []}`
- **WHEN** `searchMovies(query: "  ASTÉRIX  ")` is called
- **THEN** the request has query parameter `q == "  ASTÉRIX  "` (whitespace, casing, and accents all preserved)

#### Scenario: rethrows on 401 invalid_token

- **GIVEN** the backend responds 401 with body `{"error": {"code": "invalid_token"}}` on either method
- **WHEN** the method is called
- **THEN** the future throws `DioException` with `statusCode == 401`
- **AND** does NOT throw a Domain exception

#### Scenario: rethrows on 400 missing_profile_id

- **GIVEN** the backend responds 400 with body `{"error": {"code": "missing_profile_id"}}` (e.g. an interceptor bug failed to inject `X-Profile-Id`)
- **WHEN** the method is called
- **THEN** the future throws `DioException` with `statusCode == 400`
- **AND** does NOT throw a Domain exception

#### Scenario: rethrows on 5xx

- **GIVEN** the backend responds 500 with empty body on either method
- **WHEN** the method is called
- **THEN** the future throws `DioException` with `statusCode == 500`

#### Scenario: rethrows on network error

- **GIVEN** the network is unreachable
- **WHEN** either method is called
- **THEN** the future throws `DioException` of type `DioExceptionType.connectionError` (or equivalent)

#### Scenario: AuthInterceptor injects all three headers transparently

- **GIVEN** a session is established, a profile is selected, and `dioProvider` has the `AuthInterceptor` registered
- **WHEN** `listMoviesFor()` is called
- **THEN** the outbound request carries `Authorization: Bearer <jwt>`, `X-Device-Id: <device.id>`, and `X-Profile-Id: <profile.id>` headers
- **AND** the repository code does not reference these headers explicitly

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

