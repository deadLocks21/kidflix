## ADDED Requirements

### Requirement: Derived `currentProfileId` provider

The system SHALL expose a Riverpod provider `currentProfileIdProvider` in `lib/infrastructure/providers/current_profile_id.provider.dart` that derives `String?` from the current `SessionState` exposed by `sessionControllerProvider`.

The provider SHALL be annotated `@Riverpod(keepAlive: true)` and SHALL `ref.watch(sessionControllerProvider)` so it re-emits whenever the session state changes.

The provider SHALL return `String?` per the following exhaustive mapping over the seven `SessionState` variants:

| `SessionState` variant | Returned value |
|---|---|
| `Anonymous` | `null` |
| `OtpRequested(...)` | `null` |
| `Authenticated(session)` | `null` |
| `PinRequired(profile, _)` | `profile.id` |
| `ProfileSelected(profile, _)` | `profile.id` |
| `ManagementPinRequired(session)` | `session.profiles.firstWhere((p) => p.isMain).id` |
| `ManagingProfiles(session)` | `session.profiles.firstWhere((p) => p.isMain).id` |

The provider SHALL be implemented with an exhaustive `switch` over the sealed `SessionState` so that adding a new variant in the future surfaces as a compile-time error.

The `firstWhere(isMain)` lookup SHALL NOT have a fallback. The spec `profile-management` § `Enter profile management mode gated by main profile PIN` guarantees that `ManagementPinRequired` and `ManagingProfiles` are only reachable when the session contains exactly one profile with `isMain == true`. A missing main profile in those states is an orchestration bug and SHALL surface as an uncaught `StateError` from `firstWhere`, not as a silent `null`.

The provider's primary consumer is the `AuthInterceptor` registered on `dioProvider`, which uses it to inject the `X-Profile-Id` header on protected requests. The provider SHALL be reusable by any future component that needs the active profile id without knowing the state machine.

#### Scenario: Returns null in Anonymous state

- **GIVEN** the session controller's state is `Anonymous`
- **WHEN** a consumer reads `currentProfileIdProvider`
- **THEN** the returned value is `null`

#### Scenario: Returns null in OtpRequested state

- **GIVEN** the session controller's state is `OtpRequested(phone, expiresAt)`
- **WHEN** a consumer reads `currentProfileIdProvider`
- **THEN** the returned value is `null`

#### Scenario: Returns null in Authenticated state

- **GIVEN** the session controller's state is `Authenticated(session)` (logged in but no profile selected yet)
- **WHEN** a consumer reads `currentProfileIdProvider`
- **THEN** the returned value is `null`

#### Scenario: Returns the selected profile id in PinRequired

- **GIVEN** the session controller's state is `PinRequired(profile, session)` where `profile.id == "ar"`
- **WHEN** a consumer reads `currentProfileIdProvider`
- **THEN** the returned value is `"ar"`

#### Scenario: Returns the selected profile id in ProfileSelected

- **GIVEN** the session controller's state is `ProfileSelected(profile, session)` where `profile.id == "ar"`
- **WHEN** a consumer reads `currentProfileIdProvider`
- **THEN** the returned value is `"ar"`

#### Scenario: Returns the main profile id in ManagementPinRequired

- **GIVEN** the session controller's state is `ManagementPinRequired(session)` and `session.profiles` contains a profile with `id == "papa"` and `isMain == true`
- **WHEN** a consumer reads `currentProfileIdProvider`
- **THEN** the returned value is `"papa"`

#### Scenario: Returns the main profile id in ManagingProfiles

- **GIVEN** the session controller's state is `ManagingProfiles(session)` and `session.profiles` contains a profile with `id == "papa"` and `isMain == true`
- **WHEN** a consumer reads `currentProfileIdProvider`
- **THEN** the returned value is `"papa"`

#### Scenario: Re-emits when session state transitions

- **GIVEN** a consumer is observing `currentProfileIdProvider`
- **AND** the initial state is `Anonymous`
- **WHEN** the session transitions to `ProfileSelected(profile("ar"), session)`
- **THEN** the consumer observes the value change from `null` to `"ar"`

---

### Requirement: AuthRepository exposes `fetchProfiles` for resync

The `AuthRepository` Domain interface SHALL expose a method:

```dart
Future<List<Profile>> fetchProfiles();
```

`fetchProfiles` SHALL return the up-to-date list of profiles owned by the user identified by the current JWT. The result SHALL include each profile's `pinHash` (for offline PIN verification) and `isMain` flag, exactly as `verify-otp` returns them in its initial response.

The method SHALL NOT take any parameter. The JWT and device id are injected as headers by the central `Dio`'s `AuthInterceptor` (HTTP implementation) or read from the in-memory store (in-memory implementation).

The method SHALL be used to resync the session's profile list after the initial login, when external mutations could have happened (a new profile created on another device, a PIN updated, a profile deleted). The method SHALL NOT mutate the `SessionRepository` directly — that is the responsibility of `RefreshProfilesUseCase`.

`InMemoryAuthRepository.fetchProfiles()` SHALL return the in-memory store's current `List<Profile>` for the phone number whose `verify-otp` was last called successfully. If no `verify-otp` has succeeded yet (e.g. the repository is asked before login), the method SHALL throw `StateError`. This matches the contract: `fetchProfiles` is only callable in an authenticated state.

`DioAuthRepository.fetchProfiles()` SHALL:

1. Issue `GET /profiles` (no path suffix, no query parameter, no body).
2. On HTTP 200, parse the response body `{ "profiles": [<profile>, ...] }`, project each entry via `RemoteProfileDto.fromJson(...).toDomain()`, and return the resulting `List<Profile>` in iteration order.
3. On any `DioException`, rethrow without metier-level mapping. The contract has no documented business error code on this endpoint; `401 invalid_token` and `403 forbidden_profile` (which would not occur here since the route is exempt from `X-Profile-Id` enforcement, see the `AuthInterceptor` requirement) are surfaced generically.

The HTTP request to `GET /profiles` SHALL carry `Authorization: Bearer <jwt>` and `X-Device-Id: <uuid>` headers (injected by the `AuthInterceptor`). It SHALL NOT carry an `X-Profile-Id` header — `GET /profiles` is the exempt bootstrap route.

#### Scenario: InMemory fetchProfiles returns the current seed for the logged-in number

- **GIVEN** an `InMemoryAuthRepository` against which `verifyOtp(PhoneNumber("+33612345678"), code, device)` has succeeded, returning the seeded `[Papa, Ar, Ro]` profiles
- **WHEN** `fetchProfiles()` is called
- **THEN** the returned list equals `[Papa, Ar, Ro]` (the same instances the seed exposes)

#### Scenario: InMemory fetchProfiles throws before any login

- **GIVEN** an `InMemoryAuthRepository` against which `verifyOtp` has never been called successfully
- **WHEN** `fetchProfiles()` is called
- **THEN** the call throws `StateError`

#### Scenario: Dio fetchProfiles targets the correct path with GET

- **GIVEN** a `DioAuthRepository` whose `Dio` has `baseUrl = 'http://test.local'`
- **WHEN** `fetchProfiles()` is called
- **THEN** the underlying `Dio` issues exactly one HTTP request
- **AND** the request method is `GET`
- **AND** the request path is `/profiles`
- **AND** the request has no query parameters
- **AND** the request has no body

#### Scenario: Dio fetchProfiles parses the profiles envelope

- **GIVEN** the backend responds 200 with body `{"profiles": [{"id": "papa", "name": "Papa", "age_category": "adulte", "is_main": true, "pin_hash": "$2b$12$abc", "avatar_url": null}, {"id": "ar", "name": "Ar", "age_category": "enfant", "is_main": false, "pin_hash": null, "avatar_url": null}]}`
- **WHEN** `fetchProfiles()` is called
- **THEN** the future completes with a `List<Profile>` of length 2
- **AND** the first profile has `id == "papa"`, `isMain == true`, `pinHash == "$2b$12$abc"`
- **AND** the second profile has `id == "ar"`, `isMain == false`, `pinHash == null`

#### Scenario: Dio fetchProfiles preserves backend order

- **GIVEN** the backend responds 200 with `profiles` in order `[main, p1, p2]`
- **WHEN** `fetchProfiles()` is called
- **THEN** the returned `List<Profile>` is in the same order `[main, p1, p2]` (the repository does not sort)

#### Scenario: Dio fetchProfiles returns empty list when backend has none

- **GIVEN** the backend responds 200 with `{"profiles": []}`
- **WHEN** `fetchProfiles()` is called
- **THEN** the future completes with an empty `List<Profile>`

#### Scenario: Dio fetchProfiles rethrows on 5xx

- **GIVEN** the backend responds 500 with empty body
- **WHEN** `fetchProfiles()` is called
- **THEN** the future throws `DioException` with `statusCode == 500`
- **AND** does NOT throw a Domain exception

---

### Requirement: `RefreshProfilesUseCase` updates the session profile list

The system SHALL expose an Application-layer usecase `RefreshProfilesUseCase` in `lib/core/application/usecases/refresh_profiles.usecase.dart` that:

1. Calls `AuthRepository.fetchProfiles()` and awaits the resulting `List<Profile>`.
2. On success, mutates the current `Session` in the `SessionController` by replacing `session.profiles` with the new list, preserving the `jwt` and `device` fields.
3. On exception (network error, 5xx, etc.), leaves the session state unchanged and propagates the exception to the caller. The caller decides how to surface the failure.

The usecase SHALL be callable in any `SessionState` that carries a `Session` (per the `currentSessionProvider` mapping): `Authenticated`, `PinRequired`, `ProfileSelected`, `ManagementPinRequired`, `ManagingProfiles`. Calling it in `Anonymous` or `OtpRequested` SHALL throw `StateError` — there is no session to refresh.

The usecase SHALL NOT change which `SessionState` variant is active. A user in `ProfileSelected(profile, session)` who triggers a refresh stays in `ProfileSelected`, with `session.profiles` now reflecting the new list. If the currently-active `profile.id` is no longer in the refreshed list (the profile was deleted on another device), the session state remains `ProfileSelected` with the stale `profile` field — recovery is the responsibility of a future change. This change does not specify automatic eviction.

This change SHALL NOT wire any automatic trigger (foreground listener, pull-to-refresh, periodic timer) to this usecase. The usecase is shipped to be consumed by a future change that decides on the UX trigger.

#### Scenario: Successful refresh replaces the session profile list

- **GIVEN** a session in state `ProfileSelected(profile, Session(jwt, device, [profileA, profileB]))`
- **AND** `AuthRepository.fetchProfiles()` returns `[profileA, profileB, profileC]` (a new profile created on another device)
- **WHEN** `RefreshProfilesUseCase.execute()` is called
- **THEN** the session controller's state remains `ProfileSelected(profile, Session(jwt, device, [profileA, profileB, profileC]))`
- **AND** the `jwt` and `device` fields are preserved

#### Scenario: Refresh failure leaves the state untouched

- **GIVEN** a session in state `ProfileSelected(...)` and `fetchProfiles()` raises a `DioException`
- **WHEN** `RefreshProfilesUseCase.execute()` is called
- **THEN** the future throws the same `DioException`
- **AND** the session controller's state is unchanged

#### Scenario: Refresh in Anonymous state throws StateError

- **GIVEN** a session in state `Anonymous`
- **WHEN** `RefreshProfilesUseCase.execute()` is called
- **THEN** the future throws `StateError`

## MODIFIED Requirements

### Requirement: AuthInterceptor adds bearer + device headers

The system SHALL provide a Dio `Interceptor` named `AuthInterceptor` in `lib/infrastructure/http/auth.interceptor.dart` that automatically injects authentication headers on outbound HTTP requests.

The interceptor SHALL accept two callbacks at construction time:

- `Session? Function() session` — read at every request to source the JWT and device id.
- `String? Function() profileId` — read at every request to source the active profile id (per the `currentProfileIdProvider` mapping).

The interceptor SHALL NOT depend on Riverpod or any framework. The two callbacks SHALL be invoked at every request to read the current session and profile id lazily.

On `onRequest`:

1. **Public auth routes.** If `options.path.startsWith('/auth/')`, the interceptor SHALL call `handler.next(options)` immediately without modifying any header — the `/auth/*` endpoints are public per `API.md` § Conventions.
2. **Bootstrap profile route.** Otherwise, the interceptor SHALL invoke the `session` callback. If the returned `Session?` is non-null:
   - `options.headers['Authorization']` SHALL be set to `'Bearer <session.jwt>'`.
   - `options.headers['X-Device-Id']` SHALL be set to `session.device.id`.
3. **Profile-id injection.** If the request is NOT the bootstrap GET (i.e. NOT `options.path == '/profiles'` AND `options.method == 'GET'`), the interceptor SHALL invoke the `profileId` callback. If the returned `String?` is non-null:
   - `options.headers['X-Profile-Id']` SHALL be set to that value.
4. If the `session` callback returns `null`, the interceptor SHALL call `handler.next(options)` without adding any header. The backend SHALL be the source of truth for auth status — the interceptor SHALL NOT short-circuit with `handler.reject(...)`.
5. If the `profileId` callback returns `null` while the route is otherwise protected, the interceptor SHALL NOT add the `X-Profile-Id` header. The backend will respond `400 missing_profile_id`, surfaced as a generic `DioException`.

The bootstrap route detection (point 3) SHALL match `path == '/profiles'` with method `GET` strictly. Other `/profiles` requests (`POST /profiles`, `PATCH /profiles/:id`, `DELETE /profiles/:id`, `PUT /profiles/:id/pin`, `DELETE /profiles/:id/pin`) SHALL receive the `X-Profile-Id` header normally — these endpoints expect it (and the backend further enforces `is_main = true` on them, but that is a server-side concern).

The interceptor SHALL NOT override `onResponse` or `onError` in this change — header refresh, 401 handling, and retry are out of scope.

The same interceptor instance SHALL handle login/logout cycles and profile-selection transitions without recreating Dio: the callbacks close over `ref.read(...)` so consecutive requests after a state change pick up the latest values without rebuilding the connection pool.

#### Scenario: Skips /auth/request-otp without adding any header

- **GIVEN** an `AuthInterceptor` constructed with callbacks returning a non-null `Session(jwt: "X", device: Device(id: "Y", ...), ...)` and `profileId: "ar"`
- **WHEN** a request to `/auth/request-otp` is intercepted
- **THEN** the request reaches the next handler with NO `Authorization` header
- **AND** with NO `X-Device-Id` header
- **AND** with NO `X-Profile-Id` header

#### Scenario: Skips /auth/verify-otp without adding any header

- **GIVEN** an `AuthInterceptor` with non-null callbacks
- **WHEN** a request to `/auth/verify-otp` is intercepted
- **THEN** the request reaches the next handler with no auth headers added

#### Scenario: GET /profiles bootstrap receives JWT + device but NOT profile-id

- **GIVEN** an `AuthInterceptor` constructed with `session: () => Session(jwt: "eyJabc", device: Device(id: "uuid-1", name: null), profiles: [])` and `profileId: () => "ar"`
- **WHEN** a `GET` request to `/profiles` is intercepted
- **THEN** the forwarded request has `Authorization: Bearer eyJabc`
- **AND** `X-Device-Id: uuid-1`
- **AND** does NOT have an `X-Profile-Id` header

#### Scenario: POST /profiles receives all three headers

- **GIVEN** an `AuthInterceptor` with non-null callbacks (`session.jwt == "eyJabc"`, `session.device.id == "uuid-1"`, `profileId == "papa"`)
- **WHEN** a `POST` request to `/profiles` is intercepted
- **THEN** the forwarded request has `Authorization: Bearer eyJabc`
- **AND** `X-Device-Id: uuid-1`
- **AND** `X-Profile-Id: papa`

#### Scenario: PATCH /profiles/:id receives all three headers

- **GIVEN** an `AuthInterceptor` with non-null callbacks (`profileId == "papa"`)
- **WHEN** a `PATCH` request to `/profiles/ar` is intercepted
- **THEN** the forwarded request has `X-Profile-Id: papa`
- **AND** the `/profiles` exemption does NOT apply to this path (the path is `/profiles/ar`, not `/profiles`)

#### Scenario: GET /movies (protected route) receives all three headers

- **GIVEN** an `AuthInterceptor` with `session.jwt == "eyJabc"`, `session.device.id == "uuid-1"`, `profileId == "ar"`
- **WHEN** a `GET` request to `/movies` is intercepted
- **THEN** the forwarded request has `Authorization: Bearer eyJabc`
- **AND** `X-Device-Id: uuid-1`
- **AND** `X-Profile-Id: ar`

#### Scenario: Lets request through without any header when session is null

- **GIVEN** an `AuthInterceptor` constructed with `session: () => null` and `profileId: () => null`
- **WHEN** a request to `/movies` is intercepted
- **THEN** the request reaches the next handler with NO `Authorization` header
- **AND** with NO `X-Device-Id` header
- **AND** with NO `X-Profile-Id` header
- **AND** the interceptor does NOT call `handler.reject(...)`

#### Scenario: Profile-id null but session present injects only JWT + device

- **GIVEN** an `AuthInterceptor` with `session: () => Session(jwt: "X", device: Device(id: "Y", ...), ...)` and `profileId: () => null` (e.g. `Authenticated` state, no profile selected yet)
- **WHEN** a request to `/movies` is intercepted
- **THEN** the forwarded request has `Authorization: Bearer X`
- **AND** `X-Device-Id: Y`
- **AND** does NOT have an `X-Profile-Id` header
- **AND** the interceptor does NOT call `handler.reject(...)` (the backend will respond 400 missing_profile_id, treated as a generic DioException by the application)

#### Scenario: Reflects profile-id changes between requests

- **GIVEN** an `AuthInterceptor` with `session: () => session` and `profileId: () => mutableProfileIdRef`
- **AND** `mutableProfileIdRef == "ar"` initially
- **WHEN** a 1st request to `/movies` is sent → the request has `X-Profile-Id: ar`
- **AND** `mutableProfileIdRef` is set to `"ro"` (profile switch)
- **AND** a 2nd request is sent → the request has `X-Profile-Id: ro`
- **AND** `mutableProfileIdRef` is set to `null` (logout)
- **AND** a 3rd request is sent → the request has no `X-Profile-Id` header

#### Scenario: Reflects session changes between requests

- **GIVEN** an `AuthInterceptor` constructed with `session: () => mutableSessionRef` and `profileId: () => null`
- **AND** `mutableSessionRef == null` initially
- **WHEN** a 1st request is sent → the request has no auth headers
- **AND** `mutableSessionRef` is set to `Session(jwt: "A", device: Device(id: "D1", ...), ...)`
- **AND** a 2nd request is sent → the request has `Authorization: Bearer A` and `X-Device-Id: D1`
- **AND** `mutableSessionRef` is set back to `null`
- **AND** a 3rd request is sent → the request has no auth headers
