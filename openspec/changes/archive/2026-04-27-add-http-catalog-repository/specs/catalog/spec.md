## ADDED Requirements

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

The class SHALL accept a `Dio` instance via its constructor and SHALL NOT instantiate its own — the `Dio` is provided by `dioProvider`, which has the `AuthInterceptor` registered. The repository itself SHALL NOT add `Authorization` or `X-Device-Id` headers explicitly — these are injected transparently by the interceptor since `/movies` does not start with `/auth/`.

`listMoviesFor(AgeCategory ageCategory)` SHALL:

1. Issue `GET /movies` with query parameter `age_category=<ageCategoryToWire(ageCategory)>`.
2. On HTTP 200, parse the response body as `Map<String, dynamic>`, read the `movies` key as a `List`, cast each element to `Map<String, dynamic>`, and project each via `RemoteMovieDto.fromJson(...).toDomain()`.
3. Return the resulting `List<Movie>` in iteration order (no client-side sorting).
4. On any `DioException`, rethrow. No metier-level exception mapping — the contract has no documented business error code on this endpoint.

`searchMovies({required String query, required AgeCategory upToAgeCategory})` SHALL:

1. Issue `GET /movies/search` with query parameters `q=<query>` and `up_to_age_category=<ageCategoryToWire(upToAgeCategory)>`.
2. The `query` SHALL be passed through verbatim — no client-side trimming, lowercasing, or accent normalization. Normalization is applied symmetrically by the backend on both query and titles.
3. The repository SHALL NOT short-circuit on empty/whitespace-only `query` — minimum query length and debouncing are the UI/controller's responsibility per the Domain interface contract.
4. On HTTP 200, parse the response body using the same `{ movies: [...] }` envelope unwrap as `listMoviesFor`.
5. Return the resulting `List<Movie>` in iteration order (no client-side sorting — sorting is the application service's responsibility).
6. On any `DioException`, rethrow. No metier-level exception mapping.

The implementation SHALL NOT log raw response bodies, the `Authorization` header, or the JWT at any log level.

The implementation SHALL NOT retry failed requests — retry policy is out of scope for this change.

The age category serialization on outbound query parameters SHALL use the public top-level function `ageCategoryToWire(AgeCategory)` from `lib/core/application/dtos/age_category_wire.dart`.

#### Scenario: listMoviesFor sends the age_category query param and parses the envelope

- **GIVEN** the backend responds 200 with body `{"movies": [<movie1>, <movie2>]}` for `GET /movies?age_category=enfant`
- **WHEN** `listMoviesFor(AgeCategory.enfant)` is called
- **THEN** the request method is `GET` on path `/movies` with query parameter `age_category=enfant`
- **AND** the future completes with a `List<Movie>` of length 2 whose elements match the parsed `<movie1>` and `<movie2>`

#### Scenario: listMoviesFor preserves backend order

- **GIVEN** the backend responds 200 with `movies` in order `[m_z, m_a, m_m]`
- **WHEN** `listMoviesFor(...)` is called
- **THEN** the returned `List<Movie>` is in the same order `[m_z, m_a, m_m]` (the repository does not sort)

#### Scenario: listMoviesFor returns empty list when backend has none

- **GIVEN** the backend responds 200 with `{"movies": []}`
- **WHEN** `listMoviesFor(...)` is called
- **THEN** the future completes with an empty `List<Movie>`

#### Scenario: searchMovies sends q and up_to_age_category query params

- **GIVEN** the backend responds 200 with `{"movies": [<movie1>]}` for `GET /movies/search?q=astérix&up_to_age_category=enfant`
- **WHEN** `searchMovies(query: "astérix", upToAgeCategory: AgeCategory.enfant)` is called
- **THEN** the request method is `GET` on path `/movies/search`
- **AND** the request has query parameter `q == "astérix"` (raw, accents preserved)
- **AND** the request has query parameter `up_to_age_category == "enfant"`
- **AND** the future completes with a `List<Movie>` of length 1

#### Scenario: searchMovies passes empty query verbatim without bail-out

- **GIVEN** the backend responds 200 with `{"movies": []}` for `GET /movies/search?q=&up_to_age_category=enfant`
- **WHEN** `searchMovies(query: "", upToAgeCategory: AgeCategory.enfant)` is called
- **THEN** the request is sent to the backend with `q` parameter equal to the empty string
- **AND** the future completes with an empty `List<Movie>`

#### Scenario: searchMovies does not normalize the query client-side

- **GIVEN** the backend responds 200 with `{"movies": []}`
- **WHEN** `searchMovies(query: "  ASTÉRIX  ", upToAgeCategory: AgeCategory.enfant)` is called
- **THEN** the request has query parameter `q == "  ASTÉRIX  "` (whitespace, casing, and accents all preserved)

#### Scenario: rethrows on 401 invalid_token

- **GIVEN** the backend responds 401 with body `{"error": {"code": "invalid_token"}}` on either method
- **WHEN** the method is called
- **THEN** the future throws `DioException` with `statusCode == 401`
- **AND** does NOT throw a Domain exception

#### Scenario: rethrows on 5xx

- **GIVEN** the backend responds 500 with empty body on either method
- **WHEN** the method is called
- **THEN** the future throws `DioException` with `statusCode == 500`

#### Scenario: rethrows on network error

- **GIVEN** the network is unreachable
- **WHEN** either method is called
- **THEN** the future throws `DioException` of type `DioExceptionType.connectionError` (or equivalent)

#### Scenario: AuthInterceptor injects headers transparently

- **GIVEN** a session is established and `dioProvider` has the `AuthInterceptor` registered
- **WHEN** `listMoviesFor(...)` is called
- **THEN** the outbound request carries `Authorization: Bearer <jwt>` and `X-Device-Id: <device.id>` headers
- **AND** the repository code does not reference these headers explicitly

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

## MODIFIED Requirements

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

The method SHALL be implemented by `InMemoryCatalogRepository` and by
`DioCatalogRepository`. The HTTP implementation maps this method to a
single backend endpoint `GET /movies/search?q={query}&up_to_age_category={ageCategory}`,
preserving the 1:1 signature. The HTTP implementation does not normalize
the query client-side — it forwards the raw string and the backend
applies normalization symmetrically on both query and titles.

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
