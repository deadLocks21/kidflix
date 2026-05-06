## ADDED Requirements

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

## MODIFIED Requirements

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

