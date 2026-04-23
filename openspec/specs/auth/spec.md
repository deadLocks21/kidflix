# Authentication

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
