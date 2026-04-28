## MODIFIED Requirements

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
