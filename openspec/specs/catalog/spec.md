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
Future<List<Movie>> listMoviesFor(AgeCategory ageCategory);
```

The repository SHALL return all movies whose `ageCategory` matches the
requested category **strictly** (no hierarchical expansion at the repository
layer for this method).

The repository SHALL NOT know about rows, grouping, or the active profile.

In this change, the repository SHALL be implemented as
`InMemoryCatalogRepository` returning a hard-coded list of at least 10
fictional movies distributed across all five age categories. The stub data
SHALL include at least:

- One saga of ≥ 2 movies (so the saga row can be exercised).
- Movies from at least 3 different primary genres in the `enfant` category.
- At least one movie in each age category.

#### Scenario: Filter by age category returns only matching movies

- **GIVEN** a repository containing movies across all age categories
- **WHEN** `listMoviesFor(AgeCategory.enfant)` is called
- **THEN** the returned list contains only movies whose `ageCategory == AgeCategory.enfant`

#### Scenario: Repository does not emit hierarchical matches

- **GIVEN** a repository containing one `bebe` movie and one `enfant` movie
- **WHEN** `listMoviesFor(AgeCategory.enfant)` is called
- **THEN** the `bebe` movie is NOT in the returned list

---

### Requirement: Homepage catalog is composed by an application service

The system SHALL expose an Application-layer service
`CatalogApplicationService` with a method:

```dart
Future<List<CatalogRowDto>> buildHomeRowsFor(ProfileDto profile);
```

The service SHALL:

1. Call `CatalogRepository.listMoviesFor(profile.ageCategory)` to get the raw
   movies available to the profile.
2. Assemble a list of `CatalogRow` instances following the row composition
   rules (see subsequent requirements).
3. Apply the fixed row ordering (see row-ordering requirement).
4. Convert each `CatalogRow` into a `CatalogRowDto` (containing
   `List<MovieDto>` instead of `List<Movie>`).
5. Return only rows with at least one movie (empty rows are filtered out).

The service SHALL expose its behavior through a Riverpod provider configured
under `lib/infrastructure/providers/` per project convention.

A usecase `ListHomeCatalogUseCase` SHALL wrap the service call, accepting a
`ProfileDto` and returning `Future<List<CatalogRowDto>>`. The homepage
consumes the usecase via its Riverpod provider.

#### Scenario: Service returns only non-empty rows

- **GIVEN** a profile with no `favorites`, no `continueWatching`, and no catalog movies
- **WHEN** `buildHomeRowsFor(profile)` is called
- **THEN** the returned list is empty

#### Scenario: Service does not expose Domain entities to the UI

- **WHEN** the service returns rows
- **THEN** each row contains `MovieDto` objects (not `Movie`)
- **AND** no `Movie` Domain entity crosses the Application/UI boundary

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

The homepage SHALL expose ONLY movies whose `ageCategory` equals the
`ageCategory` of the active profile exactly. Hierarchical access (lower age
categories visible to higher-tier profiles) is OUT OF SCOPE for the
homepage — it is handled by the `search` capability, which allows a
profile to find movies with `ageCategory ≤ profile.ageCategory` via the
search bar.

#### Scenario: Ado profile sees only ado movies on the homepage

- **GIVEN** an active profile with `ageCategory == AgeCategory.ado`
- **AND** the catalog contains movies across all five age categories
- **WHEN** the homepage is built for this profile
- **THEN** all movies displayed on the homepage have `ageCategory == AgeCategory.ado`

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

### Requirement: Play button is visible but disabled in MVP

The detail modal SHALL display a "Lire" (Play) primary button. For this
change, the button SHALL be rendered in the Material disabled state
(`onPressed: null`) because the video player has not yet been implemented.

A tooltip or ancillary hint `"Lecture bientôt disponible"` MAY be attached
to the button.

The button SHALL NOT be hidden, removed, or replaced by a placeholder.

#### Scenario: Play button is disabled

- **GIVEN** the detail modal is open for a movie
- **WHEN** the user taps the Play button
- **THEN** nothing happens (button is disabled)
- **AND** no navigation or state change occurs

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
Future<List<Movie>> searchMovies({
  required String query,
  required AgeCategory upToAgeCategory,
});
```

The method SHALL return every movie that satisfies **both**:

- `movie.ageCategory` is less than or equal to `upToAgeCategory` per the
  documented order of `AgeCategory` (`bebe < enfant < ado < jeuneAdulte < adulte`).
- The normalized `query` is a substring of `movie.title` OR of
  `movie.originalTitle` (when non-null), where normalization is
  case-insensitive and accent-insensitive (see the `search` capability
  for the exact rules).

The method SHALL NOT know about rows, the active profile, sorting, or
debouncing. Sorting the results is the responsibility of the
`SearchApplicationService`. Debouncing and minimum-query-length
enforcement are responsibilities of the UI/controller layer.

The method SHALL be implemented by `InMemoryCatalogRepository` for this
change. A future HTTP implementation SHALL map this method to a single
backend endpoint (e.g., `GET /movies?q={query}&upTo={ageCategory}`),
preserving the 1:1 signature.

#### Scenario: Repository returns only movies within the allowed hierarchy

- **GIVEN** a repository containing a `bebe` movie "Shaun", an `enfant` movie "Totoro", and a `jeuneAdulte` movie "Inception", all matching the query "o"
- **WHEN** `searchMovies(query: "o", upToAgeCategory: AgeCategory.enfant)` is called
- **THEN** the returned list contains Shaun and Totoro
- **AND** the returned list does NOT contain Inception

#### Scenario: Repository applies normalized substring matching

- **GIVEN** a repository containing a movie with `title = "Astérix"`
- **WHEN** `searchMovies(query: "asterix", upToAgeCategory: AgeCategory.enfant)` is called
- **THEN** the movie is present in the returned list

#### Scenario: Repository does not sort

- **WHEN** `searchMovies(...)` is called
- **THEN** the returned list order is implementation-defined (natural iteration)
- **AND** sorting is applied by the application service, not by the repository

