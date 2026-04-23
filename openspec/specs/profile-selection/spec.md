# Profile selection

Sélection d'un profil parmi ceux attachés au compte authentifié, avec
vérification d'un PIN local (bcrypt) pour les profils protégés. Couvre la
lecture de la liste des profils depuis la session, la sélection simple
(sans PIN), la sélection avec PIN, et l'exposition du profil actif à l'UI.
Ne couvre PAS la création, modification ou suppression de profils — ces
opérations relèveront d'une future capability `profile-management`.

## Requirements

### Requirement: Profile domain model

The system SHALL represent a profile as a Domain entity `Profile` with the following fields:

- `id`: stable identifier (string)
- `name`: display name (non-empty string)
- `ageCategory`: enum among `bebe`, `enfant`, `ado`, `jeuneAdulte`, `adulte`
- `pinHash`: bcrypt hash string, nullable (null means no PIN required)
- `avatarUrl`: nullable string (not used by the UI in this change, reserved for future)

The entity SHALL be immutable and equatable by `id`.

`Profile.hasPin` SHALL be a computed boolean returning `true` when `pinHash` is non-null and non-empty.

#### Scenario: Profile without PIN

- **WHEN** a `Profile` is constructed with `pinHash = null`
- **THEN** `profile.hasPin` returns `false`

#### Scenario: Profile with PIN

- **WHEN** a `Profile` is constructed with `pinHash = "\$2b\$12\$..."` (a valid bcrypt hash)
- **THEN** `profile.hasPin` returns `true`

---

### Requirement: Profiles are read from the active session

The system SHALL NOT expose a standalone `ProfileRepository`. The profile list SHALL be part of the `Session` returned by `VerifyOtpUseCase` and restored by `RestoreSessionUseCase`.

The UI SHALL obtain the profile list from the Riverpod `sessionControllerProvider`, never from a dedicated profile provider.

When the session is in `Authenticated` or `ProfileSelected` state, the profile list SHALL be exposed to the UI as a `List<ProfileDto>`.

A `ProfileDto` SHALL contain only the fields needed by the UI: `id`, `name`, `ageCategory` as a string, `hasPin`, `avatarUrl`. It SHALL NOT expose the `pinHash` to the UI layer.

#### Scenario: UI receives DTOs, not Domain entities

- **GIVEN** a session in state `Authenticated(session)` with 3 profiles
- **WHEN** the UI reads the profile list from the session controller
- **THEN** the UI receives a `List<ProfileDto>` of length 3
- **AND** none of the DTOs expose a `pinHash` field

---

### Requirement: Select a profile without PIN

The system SHALL expose an application-layer usecase `SelectProfileUseCase` that accepts a profile id and performs the appropriate state transition based on whether the profile requires a PIN.

If the selected profile has `hasPin == false`, the usecase SHALL transition the session state directly to `ProfileSelected(profile, session)`.

If the selected profile has `hasPin == true`, the usecase SHALL transition the session state to `PinRequired(profile, session)` and NOT expose the PIN hash to the UI.

If the provided profile id does not exist in the current session, the usecase SHALL return a failure result flagged `unknownProfile` and leave the session state unchanged.

The usecase SHALL only be callable when the session is in `Authenticated`, `PinRequired`, or `ProfileSelected` state — calling it from `Anonymous` or `OtpRequested` SHALL return a failure result flagged `invalidState`.

#### Scenario: Select a profile without PIN

- **GIVEN** a session in state `Authenticated` with profile `"ar"` having `hasPin == false`
- **WHEN** `SelectProfileUseCase.execute("ar")` is called
- **THEN** the session state becomes `ProfileSelected(Profile("ar", ...), session)`

#### Scenario: Select a profile with PIN

- **GIVEN** a session in state `Authenticated` with profile `"papa"` having `hasPin == true`
- **WHEN** `SelectProfileUseCase.execute("papa")` is called
- **THEN** the session state becomes `PinRequired(Profile("papa", ...), session)`

#### Scenario: Select a non-existent profile

- **GIVEN** a session in state `Authenticated` with profiles `["papa", "ar", "ro"]`
- **WHEN** `SelectProfileUseCase.execute("ghost")` is called
- **THEN** the usecase returns a failure result flagged `unknownProfile`
- **AND** the session state remains `Authenticated`

#### Scenario: Select a profile from wrong state

- **GIVEN** a session in state `Anonymous`
- **WHEN** `SelectProfileUseCase.execute(anyId)` is called
- **THEN** the usecase returns a failure result flagged `invalidState`

---

### Requirement: Verify a profile PIN locally via bcrypt

The system SHALL expose an application-layer usecase `VerifyProfilePinUseCase` that accepts a raw PIN string and verifies it against the `pinHash` of the profile currently in `PinRequired` state.

The verification SHALL be performed by a Domain service `ProfilePinService` whose production implementation uses `bcrypt` (package `bcrypt`, Dart-pure).

The `ProfilePinService` interface SHALL expose `Future<bool> verify(String rawPin, String bcryptHash)`.

The bcrypt computation SHALL be offloaded from the main isolate (e.g. via `compute()` or equivalent) so the UI thread is not blocked during the ~100-300ms verification.

If the PIN matches, the usecase SHALL transition the session state to `ProfileSelected(profile, session)`.

If the PIN does not match, the usecase SHALL return a failure result flagged `invalidPin` and leave the session state as `PinRequired(profile, session)`.

The number of PIN attempts SHALL NOT be limited client-side in this change. Rate limiting will be handled at the API layer later.

The raw PIN string SHALL NEVER be logged, stored, or transmitted beyond the single `verify` call.

#### Scenario: Verify correct PIN

- **GIVEN** a session in state `PinRequired(Profile("papa", pinHash = bcrypt("1234")), session)`
- **WHEN** `VerifyProfilePinUseCase.execute("1234")` is called
- **THEN** the usecase returns a success result
- **AND** the session state becomes `ProfileSelected(Profile("papa", ...), session)`

#### Scenario: Verify incorrect PIN

- **GIVEN** a session in state `PinRequired(Profile("papa", pinHash = bcrypt("1234")), session)`
- **WHEN** `VerifyProfilePinUseCase.execute("0000")` is called
- **THEN** the usecase returns a failure result flagged `invalidPin`
- **AND** the session state remains `PinRequired(Profile("papa", ...), session)`

#### Scenario: Multiple failed attempts are not blocked

- **GIVEN** a session in state `PinRequired(...)`
- **WHEN** `VerifyProfilePinUseCase.execute("0000")` is called 10 times in a row
- **THEN** each call returns `invalidPin`
- **AND** no cooldown, lockout, or state change is introduced client-side

---

### Requirement: Cancel PIN entry and return to profile selection

The system SHALL allow the user to cancel PIN entry. Cancellation SHALL transition the session state from `PinRequired(profile, session)` back to `Authenticated(session)`.

The usecase responsible SHALL be a method on the session controller (e.g. `cancelPinEntry()`) — no dedicated usecase required.

#### Scenario: Cancel PIN entry

- **GIVEN** a session in state `PinRequired(profile, session)`
- **WHEN** the user cancels PIN entry from the UI
- **THEN** the session state becomes `Authenticated(session)`

---

### Requirement: Deselect active profile without clearing session

The system SHALL allow the user to return to the profile selection screen from the home page **without** clearing the authenticated session. This is the "Changer de profil" action, distinct from a full logout.

Deselecting SHALL transition the session state from `ProfileSelected(profile, session)` to `Authenticated(session)`. The JWT, device identifier, and profile list SHALL remain intact so the user can pick a different profile without re-entering the phone number or OTP.

The action SHALL be a method on the session controller (e.g. `deselectProfile()`) — no dedicated usecase required.

The home page SHALL expose this action (e.g. a "switch account" icon in the AppBar). The full-logout action (returning to the phone entry screen) SHALL NOT be available on the home page — it lives on the profile selection screen only.

#### Scenario: Deselect profile from the home page

- **GIVEN** a session in state `ProfileSelected(Profile("papa", ...), session)`
- **WHEN** the user taps the "Changer de profil" action from the home page
- **THEN** the session state becomes `Authenticated(session)`
- **AND** the JWT and profile list are unchanged

#### Scenario: Deselecting is a no-op from wrong states

- **GIVEN** a session in state `Authenticated(session)` (no active profile)
- **WHEN** `deselectProfile()` is called
- **THEN** the session state remains `Authenticated(session)`

---

### Requirement: Active profile is volatile

The active profile (carried by `ProfileSelected`) SHALL NOT be persisted to storage.

When the application is closed and reopened, if a valid session is restored, the session state SHALL be `Authenticated`, not `ProfileSelected`, forcing the user to re-select a profile (and to re-enter the PIN for profiles that have one).

#### Scenario: Active profile is lost on app restart

- **GIVEN** a running session in state `ProfileSelected(Profile("papa", ...), session)`
- **WHEN** the app is killed and relaunched
- **AND** `RestoreSessionUseCase.execute()` runs successfully
- **THEN** the session state becomes `Authenticated(session)`, not `ProfileSelected(...)`

---

### Requirement: Session state machine governs navigation

The system SHALL define a sealed class `SessionState` with exactly these variants:

- `Anonymous`
- `OtpRequested(PhoneNumber phone, DateTime expiresAt)`
- `Authenticated(Session session)`
- `PinRequired(Profile profile, Session session)`
- `ProfileSelected(Profile profile, Session session)`

The UI router (`go_router`) SHALL redirect based on the current `SessionState`:

| Current state | Target route |
|---------------|--------------|
| `Anonymous` | `/phone` |
| `OtpRequested` | `/otp` |
| `Authenticated` | `/profiles` |
| `PinRequired` | `/profiles/pin` |
| `ProfileSelected` | `/home` |

Any attempt to navigate to a route not matching the current state SHALL be intercepted by the router's `redirect` function and rewritten to the target route above.

The state transitions SHALL be linear forward:

```
Anonymous → OtpRequested → Authenticated → PinRequired → ProfileSelected
                                    └─────────────────→ ProfileSelected  (for profiles without PIN)
```

And linear backward via:

- `LogoutUseCase`: any state → `Anonymous`
- Cancel PIN: `PinRequired` → `Authenticated`
- Deselect profile: `ProfileSelected` → `Authenticated`

No other transitions SHALL be permitted.

#### Scenario: Router redirects Anonymous away from /home

- **GIVEN** a session in state `Anonymous`
- **WHEN** the user navigates to `/home`
- **THEN** the router redirects to `/phone`

#### Scenario: Router redirects Authenticated away from /phone

- **GIVEN** a session in state `Authenticated(session)`
- **WHEN** the user navigates to `/phone` (e.g. via a shared link or back button)
- **THEN** the router redirects to `/profiles`

#### Scenario: Router redirects PinRequired to /profiles/pin

- **GIVEN** a session in state `PinRequired(profile, session)`
- **WHEN** the user navigates to any route
- **THEN** the router redirects to `/profiles/pin`
