## ADDED Requirements

### Requirement: HTTP implementation of WatchProgressRepository (DioWatchProgressRepository)

The system SHALL provide an HTTP implementation of the
`WatchProgressRepository` Domain interface in
`lib/infrastructure/watch_progress/dio.watch_progress.repository.dart`,
named `DioWatchProgressRepository`. It SHALL implement the contract
defined by the `WatchProgressRepository domain interface` requirement
verbatim — same method signatures, same semantics — and additionally
satisfy the constraints below.

The class SHALL hit exactly three endpoints, mapping each Domain method
to the corresponding HTTP request documented in `API.md`
§ Progression de lecture:

| Domain method | HTTP request |
|---|---|
| `findFor({profileId, movieId})` | `GET /profiles/{profileId}/progress/{movieId}` |
| `save(WatchProgress progress)` | `PUT /profiles/{progress.profileId}/progress/{progress.movieId}` with JSON body |
| `listForProfile(profileId)` | `GET /profiles/{profileId}/progress` |

The class SHALL receive its `Dio` instance via constructor injection
(`DioWatchProgressRepository({required Dio dio})`). It SHALL NOT
instantiate or look up a `Dio` internally. The `Dio` passed in
production SHALL be the central `dioProvider` instance, configured with
the registered `AuthInterceptor`.

The class SHALL NOT set, read, or modify the `Authorization` header,
the `X-Device-Id` header, or any other auth-related header. Header
injection is the sole responsibility of the `AuthInterceptor` on the
central `Dio`. This is the structural guarantee that the repository
never bypasses or duplicates the auth layer.

The class SHALL NOT perform any metier-level mapping of HTTP errors
into Domain exceptions. Any `4xx`, `5xx`, network error, or any other
`DioException` SHALL propagate to the caller as-is. This aligns with
the posture of `DioCatalogRepository` and is justified by `API.md` not
documenting any specific error code for these endpoints beyond the
global `401 invalid_token` and `404 not_found`, which the client
treats as generic at this stage.

The class SHALL convert between Domain and wire formats via
`RemoteWatchProgressDto`
(`lib/core/application/dtos/remote_watch_progress.dto.dart`). The
repository itself SHALL NOT contain inline JSON keys (snake_case
literals) — that responsibility belongs to the DTO.

#### Scenario: findFor targets the correct path with GET

- **GIVEN** a `DioWatchProgressRepository` whose `Dio` has `baseUrl = 'http://test.local'`
- **WHEN** `findFor(profileId: 'p1', movieId: 'm1')` is called
- **THEN** the underlying `Dio` issues exactly one HTTP request
- **AND** the request method is `GET`
- **AND** the request path is `/profiles/p1/progress/m1`

#### Scenario: findFor returns null on 204 No Content

- **GIVEN** the backend responds with status `204` and an empty body
- **WHEN** `findFor(profileId: 'p1', movieId: 'm1')` is called
- **THEN** the result is `null`
- **AND** no parsing of the body is attempted

#### Scenario: findFor returns null when 200 carries a null body

- **GIVEN** the backend responds with status `200` and `data == null`
- **WHEN** `findFor(profileId: 'p1', movieId: 'm1')` is called
- **THEN** the result is `null`

#### Scenario: findFor maps a 200 JSON body to WatchProgress

- **GIVEN** the backend responds with status `200` and body `{"profile_id": "p1", "movie_id": "m1", "position_seconds": 1845, "completed": false, "updated_at": "2026-04-22T10:30:00Z"}`
- **WHEN** `findFor(profileId: 'p1', movieId: 'm1')` is called
- **THEN** the result is a `WatchProgress` with `profileId == "p1"`, `movieId == "m1"`, `positionSeconds == 1845`, `completed == false`, and `updatedAt` equal to `DateTime.parse("2026-04-22T10:30:00Z")`

#### Scenario: save targets the correct path with PUT and minimal body

- **GIVEN** a `WatchProgress` with `profileId: "p1"`, `movieId: "m1"`, `positionSeconds: 1900`, `completed: false`, `updatedAt: DateTime.utc(2026, 4, 22, 10, 30, 10)`
- **WHEN** `save(progress)` is called
- **THEN** the underlying `Dio` issues exactly one HTTP request
- **AND** the request method is `PUT`
- **AND** the request path is `/profiles/p1/progress/m1`
- **AND** the request body is `{"position_seconds": 1900, "completed": false}`
- **AND** the body does NOT contain the keys `profile_id`, `movie_id`, or `updated_at` (server-stamped)

#### Scenario: save discards the response body

- **GIVEN** the backend responds with status `200` and a body unrelated to what the client sent
- **WHEN** `save(progress)` is called
- **THEN** the call completes successfully with `Future<void>`
- **AND** no parsing of the response body is attempted

#### Scenario: listForProfile targets the correct path with GET

- **WHEN** `listForProfile('p1')` is called
- **THEN** the underlying `Dio` issues exactly one HTTP request
- **AND** the request method is `GET`
- **AND** the request path is `/profiles/p1/progress`

#### Scenario: listForProfile returns an empty list when the array is empty

- **GIVEN** the backend responds with status `200` and body `{"progress": []}`
- **WHEN** `listForProfile('p1')` is called
- **THEN** the result is an empty `List<WatchProgress>`

#### Scenario: listForProfile maps every entry of the array

- **GIVEN** the backend responds with status `200` and body `{"progress": [<entry1>, <entry2>]}` where each entry has the wire shape of a `WatchProgress`
- **WHEN** `listForProfile('p1')` is called
- **THEN** the result is a `List<WatchProgress>` of length 2
- **AND** each element corresponds to its respective wire entry, with all fields parsed correctly

#### Scenario: 4xx propagates as DioException without metier mapping

- **GIVEN** the backend responds with status `404` to a `findFor` request
- **WHEN** `findFor(profileId: 'p1', movieId: 'unknown')` is called
- **THEN** the call throws a `DioException`
- **AND** no Domain-level exception is constructed by the repository

#### Scenario: 5xx propagates as DioException

- **GIVEN** the backend responds with status `500` to a `save` request
- **WHEN** `save(progress)` is called
- **THEN** the call throws a `DioException`

#### Scenario: Repository never sets the Authorization header

- **GIVEN** a `DioWatchProgressRepository` whose `Dio` has no `AuthInterceptor` registered
- **WHEN** any of `findFor`, `save`, or `listForProfile` is called
- **THEN** the captured outbound request has no `Authorization` header set by the repository code

---

### Requirement: WatchProgressRepository implementation selection via API_BASE_URL

The system SHALL select the active `WatchProgressRepository`
implementation based on the compile-time constant
`String.fromEnvironment('API_BASE_URL')`, in
`lib/infrastructure/providers/watch_progress.repository_provider.dart`:

- When `API_BASE_URL` is the empty string (default for `flutter run` and
  `flutter test` without `--dart-define`), the provider SHALL return
  an instance of `InMemoryWatchProgressRepository`.
- When `API_BASE_URL` is non-empty (e.g.,
  `flutter run --dart-define=API_BASE_URL=http://localhost:8080`), the
  provider SHALL return an instance of `DioWatchProgressRepository`
  constructed with `ref.watch(dioProvider)`.

The provider SHALL be marked `keepAlive: true` so the chosen instance
lives for the entire app session. Switching modes requires a full
rebuild — `String.fromEnvironment` is evaluated at compile time, not at
runtime.

This selection mechanism SHALL be the only switch between
implementations: no runtime toggle, no Settings UI, no per-route
override. This is intentional and aligned with the four other
HTTP-portable repositories (`auth`, `catalog`, `profile-management`,
`downloads`) so a single `--dart-define` flag puts the entire app in
one consistent mode.

The provider SHALL remain overridable in tests via Riverpod's
standard `overrideWithValue` / `overrideWith` mechanisms — the
selection rule applies only to production resolution.

#### Scenario: Default build returns InMemoryWatchProgressRepository

- **GIVEN** the app is built without any `--dart-define=API_BASE_URL` flag
- **WHEN** the `watchProgressRepository` provider is read
- **THEN** the returned instance is of type `InMemoryWatchProgressRepository`

#### Scenario: Build with API_BASE_URL returns DioWatchProgressRepository

- **GIVEN** the app is built with `--dart-define=API_BASE_URL=http://example.com`
- **WHEN** the `watchProgressRepository` provider is read
- **THEN** the returned instance is of type `DioWatchProgressRepository`
- **AND** the instance was constructed with the `Dio` from `dioProvider`

#### Scenario: Test override remains supported

- **GIVEN** a test that overrides `watchProgressRepositoryProvider` with a fake implementation via `ProviderContainer(overrides: [...])`
- **WHEN** any consumer reads the provider
- **THEN** the fake implementation is returned, regardless of the `API_BASE_URL` value

---

### Requirement: RemoteWatchProgressDto wire-format DTO

The system SHALL define a wire-format DTO `RemoteWatchProgressDto` in
`lib/core/application/dtos/remote_watch_progress.dto.dart` that
mediates between the JSON payload of the three watch-progress endpoints
(cf. `API.md` § Progression de lecture) and the Domain `WatchProgress`
entity.

The DTO SHALL expose:

- A const constructor with all five fields required.
- `factory RemoteWatchProgressDto.fromJson(Map<String, dynamic> json)`
  — parses a single watch-progress wire payload.
- `WatchProgress toDomain()` — projects the DTO to its Domain entity.
- `Map<String, dynamic> toWireBody()` — produces the JSON body for
  `PUT /profiles/{pid}/progress/{mid}`. The returned map SHALL contain
  exactly the keys `position_seconds` and `completed`. It SHALL NOT
  contain `profile_id` or `movie_id` (which travel in the URL path),
  nor `updated_at` (which the server stamps from its own clock — any
  client-supplied value would be ignored, and a strict backend parser
  rejects unknown / extra fields with `400 invalid_request`).

The wire schema SHALL be parsed as follows. Note that `updated_at` is
**read-only** from the client's perspective: it is always present in
GET responses but never sent in PUT requests.

| Wire field | Wire type | Direction | DTO field | Domain mapping |
|---|---|---|---|---|
| `profile_id` | `String` | GET only (path on PUT) | `profileId` | direct |
| `movie_id` | `String` | GET only (path on PUT) | `movieId` | direct |
| `position_seconds` | `int` | both | `positionSeconds` | direct |
| `completed` | `bool` | both | `completed` | direct |
| `updated_at` | `String` (ISO 8601) | GET only (server-stamped) | `updatedAt: DateTime` | `DateTime.parse(...)` in `fromJson` |

`fromJson` SHALL NOT silently coerce missing required fields. A missing
required field SHALL surface as a runtime cast/null error during
parsing — fail-fast, aligned with the other `Remote*Dto` parsers.

The DTO SHALL NOT depend on `Dio`, on any repository, or on any
infrastructure concern. Its only Domain dependency is the
`WatchProgress` model.

#### Scenario: fromJson + toDomain build a faithful WatchProgress

- **GIVEN** a wire payload `{"profile_id": "p1", "movie_id": "m1", "position_seconds": 1845, "completed": false, "updated_at": "2026-04-22T10:30:00Z"}`
- **WHEN** `RemoteWatchProgressDto.fromJson(payload).toDomain()` is called
- **THEN** the returned `WatchProgress` has `profileId == "p1"`, `movieId == "m1"`, `positionSeconds == 1845`, `completed == false`, and `updatedAt == DateTime.parse("2026-04-22T10:30:00Z")`

#### Scenario: toWireBody produces the PUT body shape

- **GIVEN** a DTO with `profileId: "p1"`, `movieId: "m1"`, `positionSeconds: 1900`, `completed: false`, `updatedAt: DateTime.utc(2026, 4, 22, 10, 30, 10)`
- **WHEN** `toWireBody()` is called
- **THEN** the returned map equals `{"position_seconds": 1900, "completed": false}`
- **AND** the returned map does NOT contain the key `profile_id`
- **AND** the returned map does NOT contain the key `movie_id`
- **AND** the returned map does NOT contain the key `updated_at`

#### Scenario: toWireBody omits updated_at regardless of input precision

- **GIVEN** a DTO whose `updatedAt` carries non-zero microseconds (e.g., `DateTime.utc(2026, 4, 22, 10, 30, 10, 123, 456)`)
- **WHEN** `toWireBody()` is called
- **THEN** the returned map does NOT contain the key `updated_at`
- **AND** no fractional-second string is constructed by the DTO at all (the field is never serialized — server clock is authoritative)

#### Scenario: fromJson fails fast on missing required field

- **GIVEN** a wire payload missing the `position_seconds` key
- **WHEN** `RemoteWatchProgressDto.fromJson(payload)` is called
- **THEN** the call throws (cast/null error), without silently defaulting

## MODIFIED Requirements

### Requirement: WatchProgressRepository domain interface

The system SHALL define a Domain interface `WatchProgressRepository` in
`lib/core/domain/services/watch_progress.repository.dart` with the
following methods:

```dart
abstract interface class WatchProgressRepository {
  Future<WatchProgress?> findFor({
    required String profileId,
    required String movieId,
  });

  Future<void> save(WatchProgress progress);

  Future<List<WatchProgress>> listForProfile(String profileId);
}
```

Contract semantics:

- `findFor` — returns the current `WatchProgress` for the given
  `(profileId, movieId)`, or `null` if none exists. Never throws on
  missing data.
- `save` — upserts the progress. If a `WatchProgress` already exists
  for the same `(profileId, movieId)`, it is replaced. If not, it is
  inserted. The `updatedAt` of the passed instance is stored verbatim
  (the HTTP backend MAY override it with its own clock — clients do
  not rely on it for conflict resolution).
- `listForProfile` — returns all progresses recorded for `profileId`,
  in implementation-defined order. Used by future capabilities
  (e.g., a real `continueWatching` row). Returns an empty list when
  no progresses exist.

The repository SHALL NOT know about UI, routes, `Movie` internals, or
download concerns.

The Domain interface SHALL be implementation-agnostic. Two
implementations live under `lib/infrastructure/watch_progress/`:

- `InMemoryWatchProgressRepository` — RAM-only, used by default in
  `flutter run` (no flag) and `flutter test`. Entries are lost at app
  restart. Acceptable for local development and unit tests.
- `DioWatchProgressRepository` — HTTP, selected when
  `--dart-define=API_BASE_URL=...` is provided. See the dedicated
  `HTTP implementation of WatchProgressRepository` requirement for the
  full HTTP contract.

The active implementation is selected at compile time via the
`watchProgressRepository` provider — see the
`WatchProgressRepository implementation selection via API_BASE_URL`
requirement.

#### Scenario: Save then findFor returns the saved progress

- **GIVEN** no progress exists for `(profile "p1", movie "abc")`
- **WHEN** `save(WatchProgress(profileId: "p1", movieId: "abc", positionSeconds: 300, completed: false, updatedAt: t1))` is called
- **AND** `findFor(profileId: "p1", movieId: "abc")` is called
- **THEN** the returned `WatchProgress` has `positionSeconds == 300` and `completed == false`

#### Scenario: Second save overwrites the first

- **GIVEN** an existing progress for `(p1, abc)` with `positionSeconds = 300`
- **WHEN** `save(WatchProgress(..., positionSeconds: 600, ...))` is called for the same `(p1, abc)`
- **AND** `findFor(profileId: "p1", movieId: "abc")` is called
- **THEN** the returned `WatchProgress` has `positionSeconds == 600`

#### Scenario: findFor returns null for unknown pair

- **GIVEN** no progress exists for `(p1, xyz)`
- **WHEN** `findFor(profileId: "p1", movieId: "xyz")` is called
- **THEN** the result is `null`

#### Scenario: listForProfile returns only that profile's entries

- **GIVEN** progresses saved for `(p1, abc)`, `(p1, def)`, `(p2, abc)`
- **WHEN** `listForProfile("p1")` is called
- **THEN** the result contains exactly the progresses for `(p1, abc)` and `(p1, def)`
- **AND** does NOT contain `(p2, abc)`

---

### Requirement: Progress is saved periodically, on leave, and on completion

While the video is **playing** (not paused), the `PlayerPage` SHALL
invoke `SaveWatchProgressUseCase.execute` every **10 seconds** of
playback wall-clock time, passing the current `positionSeconds`,
`completed = false` (unless the completion threshold has been crossed
— see next requirement), and `updatedAt = now`.

The periodic timer SHALL:

- Start when playback begins.
- Pause when playback is paused.
- Resume when playback resumes.
- Stop when the page is disposed.

In addition, whenever the playback position changes by more than
**2 seconds** between two consecutive events from the engine's
`positionStream` — in either direction — the `PlayerPage` SHALL
invoke `SaveWatchProgressUseCase.execute` with the new position
out-of-band of the periodic timer. This rule captures **user seeks**
(scrubbing the seek bar): a seek is a discontinuity in the position
stream (typical playback delta between events is ≤100ms; a seek
delta is typically several seconds). Saving immediately ensures
multi-device clients see the new position without waiting up to 10s
for the next periodic tick.

The first event of the playback session SHALL NOT trigger a seek
save — there is no baseline to compare against, and the resume
dialog (if shown) already establishes the starting position. Only
deltas computed against a previously-observed position count.

The seek-save SHALL be coalesced with concurrent in-flight saves —
the same single-flight guard used by the periodic save applies. If
a save is already in-flight when a seek is detected, the seek's
save is skipped (the next periodic tick or next seek will pick up
the latest position).

On page dispose (user taps close, navigates back, or the route is
popped for any reason), the `PlayerPage` SHALL synchronously save the
**final** progress before disposing the `media_kit` player, passing
the last known `positionSeconds` and the current `completed` flag.

#### Scenario: Periodic save while playing

- **GIVEN** the video has been playing for 22 seconds without interaction
- **WHEN** the timer ticks
- **THEN** `SaveWatchProgressUseCase.execute` has been called twice (at t=10s and t=20s)
- **AND** the last call carries `positionSeconds == 20`

#### Scenario: No save while paused

- **GIVEN** the video is paused at position 45 seconds
- **WHEN** 30 seconds of wall-clock time elapse with the video still paused
- **THEN** no additional `save` call is made beyond whatever was scheduled before the pause

#### Scenario: Final save on dispose

- **GIVEN** the user has been watching for 147 seconds
- **WHEN** the user taps the close button
- **THEN** `SaveWatchProgressUseCase.execute` is called one final time with `positionSeconds == 147`
- **AND** the player is then disposed

#### Scenario: Forward seek triggers an immediate save

- **GIVEN** the video is playing at position 30 seconds
- **WHEN** the user scrubs the seek bar to position 120 seconds
- **AND** the engine emits a position event at 120 seconds
- **THEN** `SaveWatchProgressUseCase.execute` is invoked out-of-band of the periodic timer with `positionSeconds == 120`

#### Scenario: Backward seek triggers an immediate save

- **GIVEN** the video is playing at position 200 seconds
- **WHEN** the user scrubs back to position 10 seconds
- **AND** the engine emits a position event at 10 seconds
- **THEN** `SaveWatchProgressUseCase.execute` is invoked out-of-band of the periodic timer with `positionSeconds == 10`

#### Scenario: Normal playback delta does not trigger a seek save

- **GIVEN** the video is playing at position 30.0 seconds
- **WHEN** the engine emits subsequent position events at 30.05s, 30.10s, 30.15s
- **THEN** no seek-save is invoked
- **AND** only the periodic 10-second saves fire as usual

#### Scenario: First position event does not trigger a seek save

- **GIVEN** playback has just started after a resume to position 1800 seconds
- **WHEN** the very first position event from the engine arrives at 1800 seconds
- **THEN** no seek-save is invoked (no baseline to compare against)
