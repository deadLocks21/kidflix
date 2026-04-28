## MODIFIED Requirements

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

1. Call `CatalogRepository.searchMovies(query: query)` (no longer
   passes the active profile's age category — the hierarchical scope
   is enforced server-side via `X-Profile-Id` in HTTP mode, and is
   not enforced at all in in-memory mode).
2. Sort the resulting `List<Movie>` alphabetically by `title`.
3. Convert each `Movie` to a `MovieDto`.
4. Return the resulting list.

The service SHALL NOT pass `profile.ageCategory` (or any age value)
to the repository. The `ProfileDto` parameter is preserved on the
method signature because future ranking/highlighting decisions may
consume profile metadata other than the age category, but the
parameter is no longer used as an age filter.

A usecase `SearchMoviesUseCase` SHALL wrap the service call, accepting
a `String query` and a `ProfileDto profile`, returning
`Future<List<MovieDto>>`. The homepage consumes the usecase via its
Riverpod provider.

The service SHALL NOT expose `Movie` Domain entities to the UI.

#### Scenario: Service returns DTOs

- **WHEN** `searchFor(query, profile)` is called
- **THEN** each element of the returned list is a `MovieDto`
- **AND** no `Movie` Domain entity is exposed to the caller

#### Scenario: Service does not pass ageCategory to the repository

- **GIVEN** a profile with `ageCategory == AgeCategory.enfant`
- **WHEN** `searchFor("o", profile)` is called
- **THEN** `CatalogRepository.searchMovies` is called with `query: "o"` only (no `upToAgeCategory` parameter)
- **AND** the service does not inspect or forward `profile.ageCategory` to the repository

---

### Requirement: In-memory catalog repository implements searchMovies with the documented matching rules

The `InMemoryCatalogRepository` SHALL implement `searchMovies` by:

1. Iterating over the in-memory movie list (the full seed, all age
   categories) and keeping a movie if:
   - `normalizeForSearch(title).contains(normalizeForSearch(query))` OR
   - (`originalTitle != null` AND
     `normalizeForSearch(originalTitle!).contains(normalizeForSearch(query))`).
2. Returning the resulting list in its natural iteration order
   (sorting happens in the application service).

The implementation SHALL NOT apply any age-category filter. The
hierarchical scope rule documented by the `Search scope is hierarchical
ascending` requirement is enforced server-side in HTTP mode (via
`X-Profile-Id`) and is intentionally NOT enforced in in-memory mode —
in-memory tests are aware of this and adjust their fixtures or
assertions accordingly.

#### Scenario: InMemory search returns matches across all age categories

- **GIVEN** an `InMemoryCatalogRepository` with a `bebe` "Shaun le mouton", an `enfant` "Totoro", and a `jeuneAdulte` "Inception"
- **WHEN** `searchMovies(query: "o")` is called
- **THEN** the returned list contains all three movies
- **AND** no movie is filtered out based on age category at the in-memory repository layer

#### Scenario: InMemory search normalizes both sides

- **GIVEN** an `InMemoryCatalogRepository` with a movie `title = "Astérix & Obélix : L'Empire du Milieu"`
- **WHEN** `searchMovies(query: "empire")` is called
- **THEN** the returned list contains that movie

#### Scenario: InMemory search matches on originalTitle when title does not

- **GIVEN** an `InMemoryCatalogRepository` with a movie `title = "Le Monde de Nemo"` and `originalTitle = "Finding Nemo"`
- **WHEN** `searchMovies(query: "finding")` is called
- **THEN** the returned list contains that movie
