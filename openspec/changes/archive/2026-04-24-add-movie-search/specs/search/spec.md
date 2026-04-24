# Search

Recherche par titre dans le catalogue depuis la homepage. Un profil accède
aux films de sa catégorie d'âge et des catégories inférieures (portée
hiérarchique ascendante), via une barre de saisie inline qui remplace les
rows tant qu'elle est active. Couvre l'UI du mode recherche, le service
applicatif de recherche, le usecase, les règles de matching (normalisation
accents/casse + substring), les tris et les différents états (saisie vide,
aucun résultat, chargement, erreur). Ne couvre PAS la recherche fuzzy, la
recherche sur synopsis/casting/réalisateur, les filtres, l'historique de
recherches, ni les suggestions.

## ADDED Requirements

### Requirement: Search mode is toggled inline from the homepage AppBar

The homepage SHALL expose a search icon (magnifying glass) in its `AppBar`
actions. Tapping this icon SHALL activate "search mode" without navigating
to a different route.

While in search mode, the `AppBar` SHALL be replaced by a search bar
containing:

- A close icon (left) that exits search mode.
- A `TextField` with automatic focus for the search query.
- A clear (`✕`) affordance (right) visible only when the raw query is
  non-empty, that clears the `TextField` content without exiting search
  mode.

Exiting search mode SHALL return the homepage to its previous state: the
rows are visible again at their prior scroll position, the query is
cleared, and the "Changer de profil" action is available in the `AppBar`.

#### Scenario: Opening search mode

- **GIVEN** the homepage is displayed with its rows
- **WHEN** the user taps the search icon in the `AppBar`
- **THEN** the `AppBar` is replaced by a search bar with an auto-focused `TextField`
- **AND** the rows are no longer visible

#### Scenario: Closing search mode preserves home state

- **GIVEN** the user was scrolled 500 px down in the homepage rows before opening search
- **WHEN** the user taps the close icon in the search bar
- **THEN** the homepage rows are visible again at 500 px scroll position
- **AND** the `AppBar` shows the "Kidflix" title and "Changer de profil" action

#### Scenario: Clearing the query does not exit search mode

- **GIVEN** the user has typed "totoro" in the search bar
- **WHEN** the user taps the `✕` clear affordance
- **THEN** the `TextField` is empty
- **AND** the search bar is still visible with focus

---

### Requirement: Search scope is hierarchical ascending

Search results SHALL include every movie whose `ageCategory` is less than
or equal to the active profile's `ageCategory`, per the documented order
of `AgeCategory` (`bebe < enfant < ado < jeuneAdulte < adulte`).

A profile SHALL NEVER see in search results a movie whose `ageCategory` is
strictly above its own. The `bebe` profile has therefore the same scope
in search as on the homepage (only `bebe` movies).

The hierarchy SHALL be exposed by a helper on `AgeCategory` (e.g.,
extension `lowerOrEqual` returning `List<AgeCategory>`) so that the rule
lives in the Domain layer next to the enum it operates on.

#### Scenario: Ado profile searches across bebe, enfant, ado

- **GIVEN** an active profile with `ageCategory == AgeCategory.ado`
- **AND** the catalog contains a `bebe` movie "Shaun", an `enfant` movie "Totoro", an `ado` movie "Les Goonies", and a `jeuneAdulte` movie "Inception"
- **WHEN** the user searches with a query matching all four titles (e.g., "o")
- **THEN** the results include Shaun, Totoro, Les Goonies
- **AND** the results do NOT include Inception

#### Scenario: Bebe profile has the same scope as on the homepage

- **GIVEN** an active profile with `ageCategory == AgeCategory.bebe`
- **AND** the catalog contains a `bebe` movie and an `enfant` movie both matching the query
- **WHEN** the user searches
- **THEN** only the `bebe` movie is returned

#### Scenario: Adulte profile sees all categories

- **GIVEN** an active profile with `ageCategory == AgeCategory.adulte`
- **WHEN** the user searches with a query matching movies from all five age categories
- **THEN** movies from all five categories are present in the results

---

### Requirement: Matching is case-insensitive, accent-insensitive substring on title and originalTitle

A movie SHALL match the search query if, after applying the normalization
rules below, the normalized query is contained as a substring of either
the normalized `title` OR the normalized `originalTitle` (when
`originalTitle` is non-null).

Normalization rules (applied identically to the query and to each searched
field, via a pure function exposed in `lib/shared/text_normalization.dart`):

1. Trim leading and trailing whitespace.
2. Lowercase via `String.toLowerCase()`.
3. Fold common Latin diacritics to their unaccented form via an explicit
   mapping table covering at least: `à á â ä ã` → `a`, `è é ê ë` → `e`,
   `ì í î ï` → `i`, `ò ó ô ö õ` → `o`, `ù ú û ü` → `u`, `ç` → `c`,
   `ñ` → `n`, `ÿ` → `y`, and their uppercase counterparts.

The function SHALL be a pure Dart function usable and testable in
isolation from the repository.

#### Scenario: Case-insensitive match

- **GIVEN** a movie with `title = "Totoro"`
- **WHEN** the normalized query is `"TOTORO"`
- **THEN** the movie matches

#### Scenario: Accent-insensitive match on title

- **GIVEN** a movie with `title = "Astérix"`
- **WHEN** the query is `"asterix"` (no accent)
- **THEN** the movie matches

#### Scenario: Accent-insensitive match when the query is accented

- **GIVEN** a movie with `title = "Asterix"` (no accent)
- **WHEN** the query is `"Astérix"` (with accent)
- **THEN** the movie matches

#### Scenario: Substring match anywhere in the title

- **GIVEN** a movie with `title = "Harry Potter à l'école des sorciers"`
- **WHEN** the query is `"poter"`
- **THEN** the movie does NOT match (no fuzzy, "poter" ≠ "potter")

#### Scenario: Substring match mid-word

- **GIVEN** a movie with `title = "Harry Potter à l'école des sorciers"`
- **WHEN** the query is `"ecole"`
- **THEN** the movie matches (accent on "école" folded to "ecole")

#### Scenario: Match on originalTitle

- **GIVEN** a movie with `title = "Le Monde de Nemo"` and `originalTitle = "Finding Nemo"`
- **WHEN** the query is `"finding"`
- **THEN** the movie matches

#### Scenario: Query with only whitespace is not a match

- **GIVEN** any catalog
- **WHEN** the query is `"   "`
- **THEN** no search is performed (see minimum length requirement)

---

### Requirement: Minimum query length of 2 characters triggers the search

The search SHALL run only when the debounced query, after trimming
whitespace, has length `>= 2`.

When the query length is `< 2`, the UI SHALL display a neutral centered
message `"Tape au moins 2 lettres pour chercher."` and SHALL NOT call the
repository.

#### Scenario: One-character query does not trigger a search

- **WHEN** the user has typed `"t"` in the search bar
- **THEN** the results area shows the "Tape au moins 2 lettres…" message
- **AND** no call to `CatalogRepository.searchMovies` is made

#### Scenario: Two-character query triggers a search

- **WHEN** the user has typed `"to"` and the debounce elapses
- **THEN** `CatalogRepository.searchMovies` is called with the debounced query `"to"`

#### Scenario: Whitespace-only query is treated as below-minimum

- **WHEN** the user has typed `"   "` and the debounce elapses
- **THEN** the trimmed query has length 0 and the "Tape au moins 2 lettres…" message is shown

---

### Requirement: Query input is debounced before triggering the search

Keystrokes in the search `TextField` SHALL NOT each trigger a repository
call. The raw query SHALL be propagated to the repository only after the
user has stopped typing for **250 ms** (debounce window).

The debounce SHALL be implemented inside a Riverpod controller (not in the
widget) so the UI remains declarative and the timing is testable.

#### Scenario: Typing fast produces a single search

- **GIVEN** the user types `"t"`, `"o"`, `"t"`, `"o"`, `"r"`, `"o"` within 200 ms total
- **WHEN** the user stops typing
- **AND** 250 ms have elapsed since the last keystroke
- **THEN** `CatalogRepository.searchMovies` is called exactly once, with the query `"totoro"`

#### Scenario: Pausing longer than the debounce produces two searches

- **GIVEN** the user types `"to"`, waits 400 ms, then types `"ro"`
- **WHEN** the final debounce elapses
- **THEN** `searchMovies` is called twice: once with `"to"` and once with `"toro"`

---

### Requirement: Results are ordered alphabetically by title

The list of results SHALL be sorted in ascending alphabetical order of
`Movie.title`, using `String.compareTo` (locale-insensitive).

Sort order SHALL be stable — two movies with identical titles preserve
the order returned by the repository.

#### Scenario: Alphabetical sort

- **GIVEN** the filtered matches are `"Totoro"`, `"Astérix"`, `"Harry Potter…"`, `"Le Monde de Nemo"`
- **WHEN** the results are rendered
- **THEN** the display order is `"Astérix"`, `"Harry Potter…"`, `"Le Monde de Nemo"`, `"Totoro"`

---

### Requirement: Search is orchestrated by an application service and a usecase

The system SHALL expose an Application-layer service
`SearchApplicationService` with a method:

```dart
Future<List<MovieDto>> searchFor({
  required String query,
  required ProfileDto profile,
});
```

The service SHALL:

1. Derive the hierarchical scope from `profile.ageCategory` using the
   `AgeCategory` hierarchy helper.
2. Call `CatalogRepository.searchMovies(query: query, upToAgeCategory: profile.ageCategory)`.
3. Sort the resulting `List<Movie>` alphabetically by `title`.
4. Convert each `Movie` to a `MovieDto`.
5. Return the resulting list.

A usecase `SearchMoviesUseCase` SHALL wrap the service call, accepting a
`String query` and a `ProfileDto profile`, returning
`Future<List<MovieDto>>`. The homepage consumes the usecase via its
Riverpod provider.

The service SHALL NOT expose `Movie` Domain entities to the UI.

#### Scenario: Service returns DTOs

- **WHEN** `searchFor(query, profile)` is called
- **THEN** each element of the returned list is a `MovieDto`
- **AND** no `Movie` Domain entity is exposed to the caller

#### Scenario: Service applies hierarchical scope via profile

- **GIVEN** a profile with `ageCategory == AgeCategory.enfant`
- **WHEN** `searchFor("o", profile)` is called
- **THEN** `CatalogRepository.searchMovies` is called with `upToAgeCategory: AgeCategory.enfant`

---

### Requirement: Results are rendered as a vertical list of tiles

Search results SHALL be rendered as a `ListView` of vertical tiles.
Each tile SHALL display:

- A poster thumbnail on the left (ratio 2:3, width ~60 dp), loaded via
  `CachedNetworkImage` with a neutral grey fallback when
  `posterUrl == null` or when the fetch fails.
- The movie `title` on the top right, one line, ellipsis when too long.
- A single caption line underneath the title with the format
  `"YYYY · Xh YY"` or `"YYYY · XX min"` (same rules as the homepage
  movie card, reusing `formatDurationHuman`). When `year` is null, only
  the duration is displayed.
- A chevron affordance on the far right.

Tapping a tile SHALL open the `MovieDetailModal` for that movie (reusing
the existing `showMovieDetailModal` helper — no change to the modal
itself). The Play button inside the modal remains disabled.

#### Scenario: Tile shows poster, title, caption

- **GIVEN** a search result movie with `title = "Totoro"`, `year = 1988`, `duration = 86 min`, `posterUrl` set
- **WHEN** the tile is rendered
- **THEN** the poster is visible on the left
- **AND** the title `"Totoro"` is visible on the right
- **AND** the caption `"1988 · 1h26"` is visible under the title

#### Scenario: Tapping a result opens the detail modal

- **GIVEN** a visible search result tile
- **WHEN** the user taps the tile
- **THEN** the `MovieDetailModal` appears for that movie

---

### Requirement: Empty, no-results, loading, and error states are distinct

While search mode is active, the results area SHALL render exactly one of
the following states based on the controller's state:

1. **Below-minimum** — debounced query length `< 2` after trim:
   centered message `"Tape au moins 2 lettres pour chercher."`.
2. **Loading** — debounced query length `>= 2` and the async search is
   pending: `LinearProgressIndicator` under the search bar; the previous
   results (if any) MAY remain visible until new ones arrive.
3. **No results** — the search completed successfully with an empty list:
   centered message `"Aucun film ne correspond à « {query} »."` where
   `{query}` is the debounced trimmed query as typed by the user.
4. **Results** — the search completed successfully with a non-empty list:
   the vertical list of tiles is shown.
5. **Error** — the search failed: centered message
   `"Impossible de lancer la recherche."` with a "Réessayer" button that
   invalidates the results provider.

#### Scenario: Below-minimum state on empty field

- **GIVEN** search mode is active and the `TextField` is empty
- **THEN** the centered `"Tape au moins 2 lettres…"` message is shown

#### Scenario: No-results message includes the query

- **GIVEN** the user has typed `"xyz"` and no movie matches
- **WHEN** the search completes
- **THEN** the centered message reads `Aucun film ne correspond à « xyz ».`

#### Scenario: Error state exposes retry

- **GIVEN** the results provider has failed
- **WHEN** the user taps `"Réessayer"`
- **THEN** the provider is invalidated and re-executed with the current debounced query

---

### Requirement: In-memory catalog repository implements searchMovies with the documented matching rules

The `InMemoryCatalogRepository` SHALL implement `searchMovies` by:

1. Expanding `upToAgeCategory` to the list of allowed categories using
   the `AgeCategory` hierarchy helper (all categories with
   `index <= upToAgeCategory.index`).
2. Iterating over the in-memory movie list, keeping a movie if:
   - its `ageCategory` is in the expanded list, AND
   - `normalizeForSearch(title).contains(normalizeForSearch(query))` OR
     (`originalTitle != null` AND
      `normalizeForSearch(originalTitle!).contains(normalizeForSearch(query))`).
3. Returning the resulting list in its natural iteration order
   (sorting happens in the application service).

#### Scenario: InMemory search respects hierarchy

- **GIVEN** an `InMemoryCatalogRepository` with a `bebe` "Shaun le mouton" and an `enfant` "Totoro"
- **WHEN** `searchMovies(query: "o", upToAgeCategory: AgeCategory.bebe)` is called
- **THEN** the returned list contains only "Shaun le mouton"

#### Scenario: InMemory search normalizes both sides

- **GIVEN** an `InMemoryCatalogRepository` with a movie `title = "Astérix & Obélix : L'Empire du Milieu"`
- **WHEN** `searchMovies(query: "empire", upToAgeCategory: AgeCategory.enfant)` is called
- **THEN** the returned list contains that movie
