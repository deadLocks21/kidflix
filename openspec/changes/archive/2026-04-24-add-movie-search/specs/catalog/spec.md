## MODIFIED Requirements

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

## ADDED Requirements

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
