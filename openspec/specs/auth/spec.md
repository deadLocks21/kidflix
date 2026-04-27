# Authentication

## Purpose

Authentification par numéro de téléphone et code OTP à usage unique. Le flow
inclut la demande d'OTP, la vérification, le renvoi avec cooldown client, la
restauration de session au démarrage et la déconnexion. Les données de session
(JWT, profils, device id) sont persistées localement pour survivre à un
redémarrage de l'application.
## Requirements
### Requirement: Phone number validation and normalization

The system SHALL represent a phone number as a Domain value object `PhoneNumber` that validates and normalizes its input at construction time.

The normalization SHALL strip whitespace characters, dots, and hyphens from the raw input before validation.

The validation SHALL accept a 10-digit French mobile number matching the pattern `^0[67]\d{8}$` (starts with `06` or `07`).

Any other input SHALL cause the constructor to throw an `InvalidPhoneNumberException` carrying the original raw input.

Valid numbers SHALL be stored internally in E.164 form (`+33XXXXXXXXX`) so the representation is stable when the HTTP backend is added later.

#### Scenario: Accepts a well-formatted mobile number

- **WHEN** `PhoneNumber.parse("0612345678")` is called
- **THEN** the call returns a `PhoneNumber` whose E.164 representation is `"+33612345678"`

#### Scenario: Strips whitespace, dots and hyphens before validation

- **WHEN** `PhoneNumber.parse("06 12.34-56 78")` is called
- **THEN** the call returns a `PhoneNumber` whose E.164 representation is `"+33612345678"`

#### Scenario: Rejects numbers not starting with 06 or 07

- **WHEN** `PhoneNumber.parse("0112345678")` is called
- **THEN** the call throws `InvalidPhoneNumberException` carrying `"0112345678"`

#### Scenario: Rejects numbers with wrong length

- **WHEN** `PhoneNumber.parse("061234567")` is called
- **THEN** the call throws `InvalidPhoneNumberException` carrying `"061234567"`

#### Scenario: Rejects numbers with non-digit characters after normalization

- **WHEN** `PhoneNumber.parse("06ABCD5678")` is called
- **THEN** the call throws `InvalidPhoneNumberException` carrying `"06ABCD5678"`

---

### Requirement: OTP code value object

The system SHALL represent an OTP code as a Domain value object `OtpCode` that validates its input at construction time.

The validation SHALL accept exactly 6 digits. Any other input SHALL cause the constructor to throw `InvalidOtpException`.

The value object SHALL NOT store or expose any hashing logic — it is a pure input carrier.

#### Scenario: Accepts a 6-digit code

- **WHEN** `OtpCode.parse("123456")` is called
- **THEN** the call returns an `OtpCode` whose value is `"123456"`

#### Scenario: Rejects codes that are not exactly 6 digits

- **WHEN** `OtpCode.parse("12345")` is called
- **THEN** the call throws `InvalidOtpException`

#### Scenario: Rejects codes with non-digit characters

- **WHEN** `OtpCode.parse("12A456")` is called
- **THEN** the call throws `InvalidOtpException`

---

### Requirement: Request an OTP for a phone number

The system SHALL expose an application-layer usecase `RequestOtpUseCase` that accepts a `PhoneNumber` and triggers the issuance of an OTP.

If the number is known to the authentication backend, the usecase SHALL return a DTO carrying the expiration timestamp of the OTP.

If the number is unknown, the usecase SHALL catch the Domain `UnknownPhoneNumberException` and propagate a UI-ready failure result distinguishable from other errors.

The usecase SHALL transition the session state to `OtpRequested(phoneNumber, expiresAt)`. This transition SHALL NOT be persisted.

The InMemory implementation SHALL recognize the phone numbers `0612345678` and `0787654321` (in normalized form `+33612345678` and `+33787654321`) as known, and SHALL reject every other number with `UnknownPhoneNumberException`.

The InMemory implementation SHALL return an expiration timestamp 5 minutes in the future.

#### Scenario: Request OTP for a known phone number

- **WHEN** `RequestOtpUseCase.execute(PhoneNumber.parse("0612345678"))` is called against the InMemory repository
- **THEN** the usecase returns a success result with an `expiresAt` 5 minutes in the future
- **AND** the session state becomes `OtpRequested(PhoneNumber("+33612345678"), expiresAt)`

#### Scenario: Request OTP for an unknown phone number

- **WHEN** `RequestOtpUseCase.execute(PhoneNumber.parse("0699999999"))` is called against the InMemory repository
- **THEN** the usecase returns a failure result flagged `unknownPhone`
- **AND** the session state remains unchanged

---

### Requirement: Verify an OTP code

The system SHALL expose an application-layer usecase `VerifyOtpUseCase` that accepts a `PhoneNumber`, an `OtpCode` and a device identifier, and returns a DTO describing the authenticated session.

If the code is valid and not expired, the usecase SHALL return a `SessionDto` carrying the JWT, the device info, and the list of profiles with their PIN hashes (bcrypt strings for protected profiles, `null` otherwise).

If the code is incorrect, the usecase SHALL return a failure result flagged `invalidOtp`.

If the code is expired (current time past the recorded `expiresAt`), the usecase SHALL return a failure result flagged `otpExpired`.

The usecase SHALL transition the session state to `Authenticated(session)` only when the verification succeeds.

The InMemory implementation SHALL accept the hardcoded code `"123456"` and reject every other code with `InvalidOtpException`.

The InMemory implementation SHALL return for `0612345678`:

- JWT: a static non-empty placeholder string
- Profiles: `[Papa (PIN 1234, adulte), Ar (no PIN, enfant), Ro (PIN 9999, ado)]`

The InMemory implementation SHALL return for `0787654321`:

- JWT: a static non-empty placeholder string
- Profiles: `[Alice (PIN 0000, adulte), Li (no PIN, enfant)]`

The PIN hashes SHALL be bcrypt hashes of the PIN values, computed either at repository initialization or cached across calls.

#### Scenario: Verify OTP with the correct code

- **GIVEN** a session in state `OtpRequested(PhoneNumber("+33612345678"), expiresAt in the future)`
- **WHEN** `VerifyOtpUseCase.execute(phone, OtpCode.parse("123456"), deviceId)` is called against the InMemory repository
- **THEN** the usecase returns a success result carrying a `SessionDto` with 3 profiles (Papa, Ar, Ro)
- **AND** the session state becomes `Authenticated(session)`

#### Scenario: Verify OTP with an incorrect code

- **GIVEN** a session in state `OtpRequested(PhoneNumber("+33612345678"), expiresAt in the future)`
- **WHEN** `VerifyOtpUseCase.execute(phone, OtpCode.parse("000000"), deviceId)` is called
- **THEN** the usecase returns a failure result flagged `invalidOtp`
- **AND** the session state remains `OtpRequested(...)`

#### Scenario: Verify OTP after expiration

- **GIVEN** a session in state `OtpRequested(PhoneNumber("+33612345678"), expiresAt in the past)`
- **WHEN** `VerifyOtpUseCase.execute(phone, OtpCode.parse("123456"), deviceId)` is called
- **THEN** the usecase returns a failure result flagged `otpExpired`
- **AND** the session state remains `OtpRequested(...)`

---

### Requirement: Resend an OTP with client-side cooldown

The system SHALL expose an application-layer usecase `ResendOtpUseCase` that re-triggers the OTP issuance for the phone number currently in `OtpRequested` state.

The UI SHALL enforce a 60-second cooldown between consecutive resend attempts. The cooldown SHALL NOT be persisted across app restarts.

A successful resend SHALL reset the `expiresAt` timestamp in the `OtpRequested` state.

If the usecase is called while the session is not in `OtpRequested`, it SHALL return a failure result flagged `invalidState`.

#### Scenario: Resend OTP successfully

- **GIVEN** a session in state `OtpRequested(phoneNumber, expiresAt)`
- **WHEN** `ResendOtpUseCase.execute()` is called
- **THEN** the usecase returns a success result
- **AND** the session state becomes `OtpRequested(phoneNumber, newExpiresAt)` with `newExpiresAt > expiresAt`

#### Scenario: Resend OTP from wrong state

- **GIVEN** a session in state `Anonymous`
- **WHEN** `ResendOtpUseCase.execute()` is called
- **THEN** the usecase returns a failure result flagged `invalidState`

---

### Requirement: Restore session at application startup

The system SHALL expose an application-layer usecase `RestoreSessionUseCase` that attempts to rebuild a `Session` from persisted storage at application startup.

The usecase SHALL read the JWT, device info, and profile list (with PIN hashes) from the configured `SessionRepository`.

If all persisted values are present and parseable, the usecase SHALL transition the session state to `Authenticated(session)`.

If any value is missing or corrupt, the usecase SHALL leave the session state as `Anonymous` and clear any partial persisted data.

The usecase SHALL NOT restore a `ProfileSelected` state — the active profile is always volatile.

#### Scenario: Restore a complete persisted session

- **GIVEN** the `SessionRepository` contains a valid JWT, device info, and profile list
- **WHEN** `RestoreSessionUseCase.execute()` is called at app startup
- **THEN** the session state becomes `Authenticated(session)` with the persisted profiles and JWT

#### Scenario: No persisted session

- **GIVEN** the `SessionRepository` is empty
- **WHEN** `RestoreSessionUseCase.execute()` is called at app startup
- **THEN** the session state remains `Anonymous`

#### Scenario: Partial or corrupt persisted session

- **GIVEN** the `SessionRepository` contains a JWT but no profile list
- **WHEN** `RestoreSessionUseCase.execute()` is called at app startup
- **THEN** the session state becomes `Anonymous`
- **AND** the repository is cleared of all partial data

---

### Requirement: Logout

The system SHALL expose an application-layer usecase `LogoutUseCase` that clears the persisted session and transitions the session state to `Anonymous`.

The usecase SHALL clear the JWT and the profile list from the `SessionRepository`. The `device_id` SHALL be preserved across logout — it is tied to the device installation, not the user.

#### Scenario: Logout from an authenticated state

- **GIVEN** a session in state `Authenticated(session)` or `ProfileSelected(profile, session)`
- **WHEN** `LogoutUseCase.execute()` is called
- **THEN** the session state becomes `Anonymous`
- **AND** the `SessionRepository` no longer contains a JWT or profile list
- **AND** the `device_id` remains persisted

---

### Requirement: Device identifier generation and persistence

The system SHALL generate a UUID v4 `device_id` at the first application startup on a given installation, and persist it in application-managed storage.

On subsequent startups, the system SHALL read the existing `device_id` from storage and reuse it.

The `device_id` SHALL be passed as part of the `VerifyOtpUseCase` invocation so the backend can associate the session with this device.

The `device_id` SHALL survive logout — it is not cleared by `LogoutUseCase`.

#### Scenario: First launch generates a new device_id

- **GIVEN** storage contains no `device_id`
- **WHEN** the application is launched and session restoration runs
- **THEN** a new UUID v4 is generated
- **AND** the UUID is persisted in storage

#### Scenario: Subsequent launch reuses the existing device_id

- **GIVEN** storage contains a `device_id` `"abc-123"`
- **WHEN** the application is launched and session restoration runs
- **THEN** the session uses `device_id = "abc-123"` without regenerating

---

### Requirement: Domain must remain framework-agnostic

The Domain layer (`lib/core/domain/`) SHALL NOT import any Flutter, Riverpod, HTTP, or storage package.

All models, repository interfaces, service interfaces, and exceptions defined in the Domain layer SHALL be expressible in pure Dart.

Repository implementations (InMemory, persistent storage) SHALL live exclusively in `lib/infrastructure/`.

All Riverpod providers SHALL live exclusively in `lib/infrastructure/providers/`.

All imports in the project SHALL be absolute (`package:kidflix/...`) — no relative imports allowed.

#### Scenario: Domain files import only Dart SDK and other Domain files

- **WHEN** the project is statically analyzed
- **THEN** no file under `lib/core/domain/` contains an import of `package:flutter/...`, `package:riverpod/...`, `package:dio/...`, `package:http/...`, `package:shared_preferences/...`, or `package:flutter_secure_storage/...`

#### Scenario: Providers are all under infrastructure

- **WHEN** the project is statically analyzed
- **THEN** no file outside `lib/infrastructure/providers/` contains `@riverpod` annotations or `Provider<...>` declarations

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

### Requirement: RemoteProfileDto wire-format mapping

The system SHALL define `RemoteProfileDto` in `lib/core/application/dtos/remote_profile.dto.dart` as the wire-format representation of a `Profile` for all backend payloads carrying profiles (currently `verify-otp`, future `/profiles/*` endpoints).

The class name SHALL be prefixed `Remote` to distinguish it from the existing UI-facing `ProfileDto` (in `lib/core/application/dtos/profile.dto.dart`) which masks the `pinHash`. The two DTOs serve opposite directions of flow and SHALL coexist without merging.

`RemoteProfileDto` SHALL have fields:

- `id: String`
- `name: String`
- `ageCategory: AgeCategory`
- `pinHash: String?`
- `avatarUrl: String?`
- `isMain: bool`

`RemoteProfileDto.fromJson(Map<String, dynamic> json)` SHALL read the following snake_case JSON keys:

- `id` (String)
- `name` (String)
- `age_category` (String, mapped to enum — see below)
- `pin_hash` (nullable String)
- `avatar_url` (nullable String)
- `is_main` (bool)

The `age_category` mapping SHALL be:

| Wire string     | Domain `AgeCategory`        |
|-----------------|-----------------------------|
| `bebe`          | `AgeCategory.bebe`          |
| `enfant`        | `AgeCategory.enfant`        |
| `ado`           | `AgeCategory.ado`           |
| `jeune_adulte`  | `AgeCategory.jeuneAdulte`   |
| `adulte`        | `AgeCategory.adulte`        |

Any other string SHALL cause the parser to throw `FormatException` carrying the unknown value.

`RemoteProfileDto` SHALL also expose `toJson()` producing the same snake_case representation, including the inverse mapping `AgeCategory.jeuneAdulte → "jeune_adulte"`. This method is not used by the auth flow itself but is provided for the upcoming `profile-management` HTTP portage.

`RemoteProfileDto.toDomain()` SHALL construct a `Profile` Domain object with the field values copied as-is (including `pinHash` and `avatarUrl` nullables, and `isMain`).

#### Scenario: Parses a complete profile payload

- **GIVEN** the JSON object with `id: "ar"`, `name: "Ar"`, `age_category: "enfant"`, `pin_hash: null`, `avatar_url: null`, `is_main: false`
- **WHEN** `RemoteProfileDto.fromJson(...)` is called
- **THEN** the resulting DTO has `id == "ar"`, `name == "Ar"`, `ageCategory == AgeCategory.enfant`, `pinHash == null`, `avatarUrl == null`, `isMain == false`

#### Scenario: Maps "jeune_adulte" to AgeCategory.jeuneAdulte

- **GIVEN** the JSON object `{ "age_category": "jeune_adulte", ... }`
- **WHEN** `RemoteProfileDto.fromJson(...)` is called
- **THEN** the resulting DTO has `ageCategory == AgeCategory.jeuneAdulte`

#### Scenario: toJson maps AgeCategory.jeuneAdulte back to "jeune_adulte"

- **GIVEN** a `RemoteProfileDto` with `ageCategory == AgeCategory.jeuneAdulte`
- **WHEN** `dto.toJson()` is called
- **THEN** the resulting JSON object's `age_category` is `"jeune_adulte"`

#### Scenario: Round-trip preserves all fields for every age category

- **GIVEN** a JSON object with `age_category` set to each of `bebe`, `enfant`, `ado`, `jeune_adulte`, `adulte` in turn
- **WHEN** `RemoteProfileDto.fromJson(json).toJson()` is called
- **THEN** the result equals the original JSON object

#### Scenario: Rejects unknown age_category

- **GIVEN** the JSON object `{ "age_category": "extraterrestre", ... }`
- **WHEN** `RemoteProfileDto.fromJson(...)` is called
- **THEN** the call throws `FormatException` carrying the string `"extraterrestre"`

#### Scenario: toDomain produces a Profile with matching field values

- **GIVEN** a `RemoteProfileDto(id: "papa", name: "Papa", ageCategory: AgeCategory.adulte, pinHash: "$2b$12$abc", avatarUrl: null, isMain: true)`
- **WHEN** `dto.toDomain()` is called
- **THEN** the resulting `Profile` has all matching field values
- **AND** `Profile.hasPin` returns `true`

---

### Requirement: RemoteSessionDto wire-format mapping

The system SHALL define `RemoteSessionDto` in `lib/core/application/dtos/remote_session.dto.dart` as the wire-format representation of a `Session` for the `verify-otp` response.

The class name SHALL be prefixed `Remote` to distinguish it from the existing UI-facing `SessionDto` (in `lib/core/application/dtos/session.dto.dart`) which masks the `jwt` and exposes `Device` only as `deviceId`. The two DTOs serve opposite directions of flow and SHALL coexist without merging.

`RemoteSessionDto` SHALL have fields:

- `jwt: String`
- `device: RemoteDeviceDto`
- `profiles: List<RemoteProfileDto>`

`RemoteSessionDto.fromJson(Map<String, dynamic> json)` SHALL read:

- `jwt` (String)
- `device` (Map, parsed via `RemoteDeviceDto.fromJson`)
- `profiles` (List, each element parsed via `RemoteProfileDto.fromJson`)

`RemoteSessionDto.toDomain()` SHALL construct a `Session` Domain object with `jwt`, `device.toDomain()`, and the profiles list mapped via `RemoteProfileDto.toDomain()` and wrapped in `List.unmodifiable`.

The system SHALL define `RemoteDeviceDto` **inline in the same file** (no separate `remote_device.dto.dart`). `RemoteDeviceDto` SHALL have fields:

- `id: String`
- `name: String?`

`RemoteDeviceDto.fromJson(Map<String, dynamic> json)` SHALL read `id` (non-nullable String) and `name` (nullable String).

`RemoteDeviceDto.toDomain()` SHALL construct a `Device` Domain object with the same field values.

The choice to keep `RemoteDeviceDto` inline is intentional and SHALL be documented in a doc-comment: `Device` only appears in the `verify-otp` response per the current `API.md` contract, so a separate file would be premature.

#### Scenario: Parses a complete verify-otp response

- **GIVEN** a JSON object with `jwt: "eyJabc"`, `device: { id: "9b2-uuid", name: "iPhone de Papa" }`, and 2 profiles (Papa adulte main, Ar enfant non-main)
- **WHEN** `RemoteSessionDto.fromJson(...)` is called
- **THEN** the DTO has `jwt == "eyJabc"`, `device == RemoteDeviceDto(id: "9b2-uuid", name: "iPhone de Papa")`, and `profiles.length == 2`

#### Scenario: Parses null device.name

- **GIVEN** the JSON object containing `"device": { "id": "abc", "name": null }`
- **WHEN** `RemoteSessionDto.fromJson(...)` is called
- **THEN** the DTO's `device.name` is `null`

#### Scenario: toDomain produces a Session with a properly populated Device and Profiles list

- **GIVEN** a `RemoteSessionDto` parsed from a 2-profile example
- **WHEN** `dto.toDomain()` is called
- **THEN** the resulting `Session.jwt` is `"eyJabc"`
- **AND** `Session.device` equals `Device(id: "9b2-uuid", name: "iPhone de Papa")`
- **AND** `Session.profiles` is a `List<Profile>` of length 2 containing the Papa and Ar profiles in order

#### Scenario: Empty profiles list

- **GIVEN** the JSON object `{ "jwt": "...", "device": {...}, "profiles": [] }`
- **WHEN** `RemoteSessionDto.fromJson(...).toDomain()` is called
- **THEN** the resulting `Session.profiles` is an empty list (no exception)

---

### Requirement: Wire DTOs separation from UI DTOs

The system SHALL maintain two distinct DTO families in `lib/core/application/dtos/` that SHALL NOT be merged:

- **UI-facing DTOs** (existing): `profile.dto.dart`, `session.dto.dart`, `movie.dto.dart`, etc. Direction of flow: `Domain → DTO → UI`. They mask sensitive fields (`pinHash`, `jwt`) so the UI layer cannot accidentally expose them. They expose only `fromDomain()` constructors.
- **Wire-format DTOs** (new, prefixed `remote_`): `remote_profile.dto.dart`, `remote_session.dto.dart`. Direction of flow: `JSON → DTO → Domain` (and reverse for outgoing payloads). They contain ALL backend-emitted fields including `pinHash` and `jwt`. They expose `fromJson()`, `toJson()`, and `toDomain()` methods.

UI code (`lib/ui/`) SHALL NOT import from `remote_*.dto.dart` files.

Repository implementations (`lib/infrastructure/`) SHALL NOT import the UI-facing DTOs (`ProfileDto`, `SessionDto`).

The class names SHALL reflect the family: UI-facing classes have no prefix (`ProfileDto`), wire classes are prefixed `Remote` (`RemoteProfileDto`).

#### Scenario: UI does not import wire DTOs

- **WHEN** the project is statically analyzed
- **THEN** no file under `lib/ui/` contains an import of `package:kidflix/core/application/dtos/remote_*.dart`

#### Scenario: Infrastructure does not import UI DTOs

- **WHEN** the project is statically analyzed
- **THEN** no file under `lib/infrastructure/` contains an import of `package:kidflix/core/application/dtos/profile.dart` or `package:kidflix/core/application/dtos/session.dart` (the non-`remote_` UI versions)

#### Scenario: Wire DTOs file naming convention

- **WHEN** the `lib/core/application/dtos/` directory is listed
- **THEN** every file whose corresponding class includes a `fromJson` factory (i.e. parses a backend payload) has a filename starting with `remote_`
- **AND** every file whose corresponding class only exposes `fromDomain` (i.e. projects a Domain object for the UI) has a filename NOT starting with `remote_`

---

### Requirement: AuthRepository implementation selection via API_BASE_URL

The system SHALL select between the in-memory and HTTP implementations of `AuthRepository` based on the compile-time constant `String.fromEnvironment('API_BASE_URL')`.

The selection logic SHALL live in the Riverpod provider `authRepositoryProvider` (`lib/infrastructure/providers/auth.repository_provider.dart`) and SHALL behave as follows:

```dart
const baseUrl = String.fromEnvironment('API_BASE_URL');
if (baseUrl.isEmpty) {
  return InMemoryAuthRepository(pin, store);  // existing behavior
}
return DioAuthRepository(ref.watch(dioProvider));  // new behavior
```

The selection SHALL happen at build time via the `--dart-define` mechanism — `String.fromEnvironment` is a `const` expression evaluated at compilation, NOT a runtime lookup of an environment variable.

When `API_BASE_URL` is unset (default), the provider SHALL return the existing `InMemoryAuthRepository` so that:

- Developers running `flutter run` without the flag get the in-memory behavior identical to before this change.
- Tests running `flutter test` (which never pass `--dart-define`) continue to use the in-memory implementation.

When `API_BASE_URL` is set to a non-empty string, the provider SHALL return a `DioAuthRepository` consuming the centralized `dioProvider` (whose own `baseUrl` was configured from the same compile-time constant).

The provider SHALL remain `@Riverpod(keepAlive: true)` so the chosen implementation is created once per app lifetime and its internal state (e.g. in-memory store seed) is preserved across consumer rebuilds.

Switching between in-memory and HTTP modes SHALL require a full app rebuild (`flutter run` with or without the flag) — no runtime toggle is provided in this change.

#### Scenario: Default build returns InMemoryAuthRepository

- **GIVEN** the app is built without `--dart-define=API_BASE_URL`
- **WHEN** any consumer reads `authRepositoryProvider`
- **THEN** the returned instance is of runtime type `InMemoryAuthRepository`

#### Scenario: Build with API_BASE_URL returns DioAuthRepository

- **GIVEN** the app is built with `--dart-define=API_BASE_URL=http://localhost:8080`
- **WHEN** any consumer reads `authRepositoryProvider`
- **THEN** the returned instance is of runtime type `DioAuthRepository`

#### Scenario: Test override remains supported

- **GIVEN** a test that overrides `authRepositoryProvider` with a fake implementation via `ProviderContainer.test`
- **WHEN** the consumer reads `authRepositoryProvider` in the test
- **THEN** the fake is returned regardless of the `API_BASE_URL` value the test was compiled with

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

