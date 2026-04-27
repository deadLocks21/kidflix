## ADDED Requirements

### Requirement: Centralized Dio HTTP client provider

The system SHALL expose a Riverpod provider `dioProvider` in `lib/infrastructure/providers/dio.provider.dart` that returns a single shared `Dio` instance for all HTTP repositories.

The provider SHALL be annotated `@Riverpod(keepAlive: true)` so the underlying `Dio` (and its connection pool) lives for the application's lifetime.

The `Dio` instance SHALL be configured with:

- `baseUrl` = `const String.fromEnvironment('API_BASE_URL')` (compile-time).
- `connectTimeout` = 10 seconds.
- `receiveTimeout` = 30 seconds.
- `contentType` = `'application/json'`.
- `responseType` = `ResponseType.json`.

The provider SHALL NOT register any interceptor in this change — the two `/auth/*` endpoints are public and require no `Authorization` or `X-Device-Id` header. The provider SHALL document, via doc-comment, that authentication interceptors are expected to be added when the first protected capability is ported (catalog or profile-management).

The provider SHALL be importable from any `lib/infrastructure/<feature>/` implementation that needs to make HTTP calls. Repositories SHALL NOT instantiate their own `Dio`.

#### Scenario: Provider returns a configured Dio instance

- **WHEN** a consumer reads `dioProvider`
- **THEN** the returned object is of type `Dio`
- **AND** `dio.options.connectTimeout` is `Duration(seconds: 10)`
- **AND** `dio.options.receiveTimeout` is `Duration(seconds: 30)`
- **AND** `dio.options.contentType` is `'application/json'`

#### Scenario: Provider has no auth interceptors in this change

- **WHEN** a consumer reads `dioProvider`
- **THEN** `dio.interceptors` does NOT contain any interceptor that reads or sets the `Authorization` or `X-Device-Id` headers

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

The implementation SHALL read the `error.code` from the response body defensively (`response?.data?['error']?['code'] as String?`) — never crash when the body is absent, malformed, or non-JSON.

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

---

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
