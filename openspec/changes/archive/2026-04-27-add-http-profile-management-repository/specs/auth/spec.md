## ADDED Requirements

### Requirement: Derived `currentSession` provider

The system SHALL expose a Riverpod provider `currentSessionProvider` in `lib/infrastructure/providers/current_session.provider.dart` that derives `Session?` from the current `SessionState` exposed by `sessionControllerProvider`.

The provider SHALL be annotated `@Riverpod(keepAlive: true)` and SHALL `ref.watch(sessionControllerProvider)` so it re-emits whenever the session state changes.

The provider SHALL return `Session?` per the following exhaustive mapping over the seven `SessionState` variants:

| `SessionState` variant | Returned value |
|---|---|
| `Anonymous` | `null` |
| `OtpRequested(...)` | `null` |
| `Authenticated(session)` | `session` |
| `PinRequired(profile, session)` | `session` |
| `ProfileSelected(profile, session)` | `session` |
| `ManagementPinRequired(session)` | `session` |
| `ManagingProfiles(session)` | `session` |

The provider SHALL be implemented with an exhaustive `switch` over the sealed `SessionState` so that adding a new variant in the future surfaces as a compile-time error.

The provider's primary consumer is the `AuthInterceptor` registered on `dioProvider`, but it SHALL be reusable by any other component that needs the active session without knowing the state machine (logging interceptor, debug overlay, future refresh interceptor).

#### Scenario: Returns null in Anonymous state

- **GIVEN** the session controller's state is `Anonymous`
- **WHEN** a consumer reads `currentSessionProvider`
- **THEN** the returned value is `null`

#### Scenario: Returns null in OtpRequested state

- **GIVEN** the session controller's state is `OtpRequested(phone, expiresAt)`
- **WHEN** a consumer reads `currentSessionProvider`
- **THEN** the returned value is `null`

#### Scenario: Returns the session in Authenticated state

- **GIVEN** the session controller's state is `Authenticated(session)`
- **WHEN** a consumer reads `currentSessionProvider`
- **THEN** the returned value is the same `Session` instance

#### Scenario: Returns the session in any state that carries one

- **GIVEN** the session controller's state is `PinRequired`, `ProfileSelected`, `ManagementPinRequired`, or `ManagingProfiles`
- **WHEN** a consumer reads `currentSessionProvider`
- **THEN** the returned value is the embedded `Session` instance

---

### Requirement: AuthInterceptor adds bearer + device headers

The system SHALL provide a Dio `Interceptor` named `AuthInterceptor` in `lib/infrastructure/http/auth.interceptor.dart` that automatically injects authentication headers on outbound HTTP requests.

The interceptor SHALL accept a `Session? Function()` callback at construction time and SHALL NOT depend on Riverpod or any framework. The callback SHALL be invoked at every request to read the current session lazily.

On `onRequest`:

1. If `options.path.startsWith('/auth/')`, the interceptor SHALL call `handler.next(options)` immediately without modifying headers — the `/auth/*` endpoints are public per `API.md` § Conventions.
2. Otherwise, the interceptor SHALL invoke the callback. If the returned `Session?` is non-null:
   - `options.headers['Authorization']` SHALL be set to `'Bearer <session.jwt>'`.
   - `options.headers['X-Device-Id']` SHALL be set to `session.device.id`.
3. If the callback returns `null`, the interceptor SHALL call `handler.next(options)` without adding any header. The backend SHALL be the source of truth for auth status — the interceptor SHALL NOT short-circuit with `handler.reject(...)`.

The interceptor SHALL NOT override `onResponse` or `onError` in this change — header refresh, 401 handling, and retry are out of scope.

The same interceptor instance SHALL handle login/logout cycles without recreating Dio: the callback closes over a Riverpod `ref` and reads the latest session via `ref.read(currentSessionProvider)`, so consecutive requests after a state change pick up the new session without rebuilding the connection pool.

#### Scenario: Skips /auth/request-otp without adding headers

- **GIVEN** an `AuthInterceptor` constructed with a callback that returns a non-null `Session(jwt: "X", device: Device(id: "Y", ...), ...)`
- **WHEN** a request to `/auth/request-otp` is intercepted
- **THEN** the request reaches the next handler with NO `Authorization` header
- **AND** with NO `X-Device-Id` header

#### Scenario: Skips /auth/verify-otp without adding headers

- **GIVEN** an `AuthInterceptor` with a non-null session callback
- **WHEN** a request to `/auth/verify-otp` is intercepted
- **THEN** the request reaches the next handler with no auth headers added

#### Scenario: Adds bearer and device headers when session is present

- **GIVEN** an `AuthInterceptor` constructed with `() => Session(jwt: "eyJabc", device: Device(id: "uuid-1", name: null), profiles: [])`
- **WHEN** a request to `/profiles/123` is intercepted
- **THEN** the forwarded request has `Authorization: Bearer eyJabc`
- **AND** `X-Device-Id: uuid-1`

#### Scenario: Lets request through without headers when session is null

- **GIVEN** an `AuthInterceptor` constructed with `() => null`
- **WHEN** a request to `/profiles/123` is intercepted
- **THEN** the request reaches the next handler with NO `Authorization` header
- **AND** with NO `X-Device-Id` header
- **AND** the interceptor does NOT call `handler.reject(...)`

#### Scenario: Reflects session changes between requests

- **GIVEN** an `AuthInterceptor` constructed with `() => mutableSessionRef`
- **AND** `mutableSessionRef == null` initially
- **WHEN** a 1st request is sent → the request has no auth headers
- **AND** `mutableSessionRef` is set to `Session(jwt: "A", device: Device(id: "D1", ...), ...)`
- **AND** a 2nd request is sent → the request has `Authorization: Bearer A` and `X-Device-Id: D1`
- **AND** `mutableSessionRef` is set back to `null`
- **AND** a 3rd request is sent → the request has no auth headers

---

### Requirement: Shared `readErrorCode` helper

The system SHALL expose a top-level function `readErrorCode(Response<dynamic>? response) → String?` in `lib/infrastructure/http/error_code.dart`, shared by every `dio.<feature>.repository.dart` that needs to read the machine-readable `error.code` from a JSON error body.

The function SHALL be defensive: it SHALL return `null` for any deviation from the documented `{ "error": { "code": String, ... } }` envelope, including:

- `response == null`.
- `response.data` is not a `Map` (e.g. plain string, byte stream, `null`).
- `response.data['error']` is not a `Map`.
- `response.data['error']['code']` is not a `String`.

In all other cases, the function SHALL return the `String` value of `error.code`.

The function SHALL NEVER throw — callers can use it without try/catch.

`DioAuthRepository` SHALL be updated to consume this helper instead of its prior private `_readErrorCode` method. `DioProfileManagementRepository` SHALL consume it from introduction.

#### Scenario: Reads error.code from a well-formed body

- **GIVEN** a `Response` with `data == { "error": { "code": "invalid_otp" } }`
- **WHEN** `readErrorCode(response)` is called
- **THEN** the returned value is `"invalid_otp"`

#### Scenario: Returns null when error.code is absent

- **GIVEN** a `Response` with `data == { "error": { "message": "..." } }`
- **WHEN** `readErrorCode(response)` is called
- **THEN** the returned value is `null`

#### Scenario: Returns null when body is a plain string

- **GIVEN** a `Response` with `data == "plain text not json"`
- **WHEN** `readErrorCode(response)` is called
- **THEN** the returned value is `null`

#### Scenario: Returns null when response itself is null

- **WHEN** `readErrorCode(null)` is called
- **THEN** the returned value is `null`

#### Scenario: Returns null when error.code is non-string

- **GIVEN** a `Response` with `data == { "error": { "code": 42 } }`
- **WHEN** `readErrorCode(response)` is called
- **THEN** the returned value is `null`

## MODIFIED Requirements

### Requirement: Centralized Dio HTTP client provider

The system SHALL expose a Riverpod provider `dioProvider` in `lib/infrastructure/providers/dio.provider.dart` that returns a single shared `Dio` instance for all HTTP repositories.

The provider SHALL be annotated `@Riverpod(keepAlive: true)` so the underlying `Dio` (and its connection pool) lives for the application's lifetime.

The `Dio` instance SHALL be configured with:

- `baseUrl` = `const String.fromEnvironment('API_BASE_URL')` (compile-time).
- `connectTimeout` = 10 seconds.
- `receiveTimeout` = 30 seconds.
- `contentType` = `'application/json'`.
- `responseType` = `ResponseType.json`.

The provider SHALL register an `AuthInterceptor` on `dio.interceptors`, constructed with a callback `() => ref.read(currentSessionProvider)`. The callback uses `ref.read` (not `ref.watch`) so that login/logout transitions do NOT rebuild Dio — the interceptor reads the latest session lazily at every request.

The provider SHALL NOT register additional interceptors in this change (logging, retry, refresh). Future portages may extend the registration — the contract for `AuthInterceptor` is documented under its own requirement.

The provider SHALL be importable from any `lib/infrastructure/<feature>/` implementation that needs to make HTTP calls. Repositories SHALL NOT instantiate their own `Dio`.

#### Scenario: Provider returns a configured Dio instance

- **WHEN** a consumer reads `dioProvider`
- **THEN** the returned object is of type `Dio`
- **AND** `dio.options.connectTimeout` is `Duration(seconds: 10)`
- **AND** `dio.options.receiveTimeout` is `Duration(seconds: 30)`
- **AND** `dio.options.contentType` is `'application/json'`

#### Scenario: Provider has an AuthInterceptor registered

- **WHEN** a consumer reads `dioProvider`
- **THEN** `dio.interceptors.whereType<AuthInterceptor>().length` is `1`

#### Scenario: Empty API_BASE_URL produces an empty baseUrl

- **GIVEN** the app is built without `--dart-define=API_BASE_URL`
- **WHEN** a consumer reads `dioProvider`
- **THEN** `dio.options.baseUrl` is an empty string

---

### Requirement: HTTP implementation of AuthRepository (DioAuthRepository)

The system SHALL provide an HTTP implementation `DioAuthRepository implements AuthRepository` in `lib/infrastructure/auth/dio.auth.repository.dart` that calls the backend `/auth/*` endpoints documented in `API.md`.

The class SHALL accept a `Dio` instance via its constructor and SHALL NOT instantiate its own — the `Dio` is provided by `dioProvider`.

`requestOtp(PhoneNumber phoneNumber)` SHALL:

1. Issue `POST /auth/request-otp` with body `{ "phone_number": <phoneNumber.e164> }`.
2. On HTTP 200, parse `{ "expires_at": "<ISO 8601>" }` from the response body and return the parsed `DateTime`.
3. On `DioException` whose response has `statusCode == 404` and `body.error.code == "unknown_phone_number"`, throw `UnknownPhoneNumberException(phoneNumber)`.
4. On any other `DioException` (network errors, 5xx, 429 rate-limited, malformed payload), rethrow the original `DioException` so the application service can surface it as a generic error.

`verifyOtp(PhoneNumber phoneNumber, OtpCode code, Device device)` SHALL:

1. Issue `POST /auth/verify-otp` with body `{ "phone_number": <phoneNumber.e164>, "code": <code.value>, "device_id": <device.id>, "device_name": <device.name> }`. The `device_name` key SHALL be omitted when `device.name == null`.
2. On HTTP 200, parse the response via `RemoteSessionDto.fromJson` and return `sessionDto.toDomain()`. The returned `Session.device` SHALL be the `Device` reconstructed from the response's `device` field (NOT the `device` parameter passed to `verifyOtp`).
3. On `DioException` whose response has `statusCode == 401` and `body.error.code == "invalid_otp"`, throw `InvalidOtpException()`.
4. On `DioException` whose response has `statusCode == 410` and `body.error.code == "otp_expired"`, throw `OtpExpiredException()`.
5. On `DioException` whose response has `statusCode == 404` and `body.error.code == "unknown_phone_number"`, throw `UnknownPhoneNumberException(phoneNumber)`.
6. On any other `DioException`, rethrow.

The implementation SHALL read the `error.code` from the response body via the shared top-level function `readErrorCode(Response?)` from `lib/infrastructure/http/error_code.dart` — never via a private duplicate.

The implementation SHALL NOT log raw response bodies or PII (phone numbers, OTP codes, JWT) at any log level.

The implementation SHALL NOT retry failed requests — retry policy is out of scope for this change.

#### Scenario: requestOtp returns the parsed expiration

- **GIVEN** the backend responds 200 with body `{ "expires_at": "2026-04-27T15:00:00Z" }`
- **WHEN** `requestOtp(PhoneNumber.parse("0612345678"))` is called
- **THEN** the future completes with `DateTime.parse("2026-04-27T15:00:00Z")`

#### Scenario: requestOtp maps 404 unknown_phone_number to domain exception

- **GIVEN** the backend responds 404 with body `{ "error": { "code": "unknown_phone_number" } }`
- **WHEN** `requestOtp(PhoneNumber.parse("0699999999"))` is called
- **THEN** the future throws `UnknownPhoneNumberException` carrying the `PhoneNumber` whose E.164 form is `"+33699999999"`

#### Scenario: requestOtp rethrows on rate limiting

- **GIVEN** the backend responds 429 with body `{ "error": { "code": "rate_limited" } }`
- **WHEN** `requestOtp` is called
- **THEN** the future throws `DioException` (NOT a Domain exception)
- **AND** the exception's response has `statusCode == 429`

#### Scenario: verifyOtp builds Session from the JSON response

- **GIVEN** the backend responds 200 with body containing `jwt: "eyJabc"`, `device: { id: "9b2-uuid", name: "iPhone backend-normalized" }`, and one Papa profile (`age_category: "adulte"`, `is_main: true`, `pin_hash: "$2b$12$..."`, `avatar_url: null`)
- **WHEN** `verifyOtp(phone, code, Device(id: "9b2-uuid", name: "iPhone client-side"))` is called
- **THEN** the returned `Session.jwt` is `"eyJabc"`
- **AND** the returned `Session.device.name` is `"iPhone backend-normalized"` (the JSON response's value, NOT the parameter's value)
- **AND** the returned `Session.profiles` has length 1 with the Papa profile reconstructed via `RemoteProfileDto.toDomain()`

#### Scenario: verifyOtp omits device_name from request body when null

- **GIVEN** `device == Device(id: "abc", name: null)`
- **WHEN** `verifyOtp(phone, code, device)` is called
- **THEN** the request body sent to the backend contains keys `phone_number`, `code`, `device_id`
- **AND** the request body does NOT contain a `device_name` key

#### Scenario: verifyOtp maps 401 invalid_otp to domain exception

- **GIVEN** the backend responds 401 with body `{ "error": { "code": "invalid_otp" } }`
- **WHEN** `verifyOtp` is called
- **THEN** the future throws `InvalidOtpException`

#### Scenario: verifyOtp maps 410 otp_expired to domain exception

- **GIVEN** the backend responds 410 with body `{ "error": { "code": "otp_expired" } }`
- **WHEN** `verifyOtp` is called
- **THEN** the future throws `OtpExpiredException`

#### Scenario: verifyOtp maps 404 unknown_phone_number to domain exception

- **GIVEN** the backend responds 404 with body `{ "error": { "code": "unknown_phone_number" } }`
- **WHEN** `verifyOtp(phone, code, device)` is called for `phone` whose E.164 form is `"+33699999999"`
- **THEN** the future throws `UnknownPhoneNumberException` carrying that same `PhoneNumber`

#### Scenario: verifyOtp rethrows on 5xx

- **GIVEN** the backend responds 500 with empty body
- **WHEN** `verifyOtp` is called
- **THEN** the future throws `DioException` with `statusCode == 500`

#### Scenario: verifyOtp survives malformed error body

- **GIVEN** the backend responds 401 with body `"plain text not json"`
- **WHEN** `verifyOtp` is called
- **THEN** the future throws `DioException` (since `error.code` cannot be read, the implementation rethrows rather than guessing)
- **AND** does NOT throw `_TypeError` or `_CastError` from the parsing
