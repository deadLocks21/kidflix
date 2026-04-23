## MODIFIED Requirements

### Requirement: Profile domain model

The system SHALL represent a profile as a Domain entity `Profile` with the following fields:

- `id`: stable identifier (string)
- `name`: display name (non-empty string)
- `ageCategory`: enum among `bebe`, `enfant`, `ado`, `jeuneAdulte`, `adulte`
- `pinHash`: bcrypt hash string, nullable (null means no PIN required)
- `avatarUrl`: nullable string (not used by the UI in this change, reserved for future)
- `isMain`: boolean flag marking the main profile of the account. Defaults to `false` in the constructor. Immutable from the app's perspective — no Domain or Application operation SHALL mutate this field.

The entity SHALL be immutable and equatable by `id`.

`Profile.hasPin` SHALL be a computed boolean returning `true` when `pinHash` is non-null and non-empty.

The following invariants on a `Session.profiles` list SHALL be guaranteed by the source of truth (backend, or in tests, the fake data):

1. Exactly one profile in the list has `isMain == true`.
2. The profile with `isMain == true` has `pinHash != null && pinHash.isNotEmpty`.
3. Profiles created from the app always have `isMain == false`.

The app SHALL NOT attempt to enforce invariants 1 and 2 at runtime. If the backend returns a malformed list, the relevant usecase (`EnterManagementModeUseCase`) SHALL fail cleanly with a `MissingMainProfileException` rather than crash.

#### Scenario: Profile without PIN

- **WHEN** a `Profile` is constructed with `pinHash = null`
- **THEN** `profile.hasPin` returns `false`

#### Scenario: Profile with PIN

- **WHEN** a `Profile` is constructed with `pinHash = "\$2b\$12\$..."` (a valid bcrypt hash)
- **THEN** `profile.hasPin` returns `true`

#### Scenario: Main profile flag is independent of other fields

- **WHEN** a `Profile` is constructed with `isMain = true` and `pinHash = "\$2b\$12\$..."`
- **THEN** `profile.isMain` returns `true`
- **AND** `profile.hasPin` returns `true`

#### Scenario: isMain defaults to false

- **WHEN** a `Profile` is constructed without specifying `isMain`
- **THEN** `profile.isMain` returns `false`

---

### Requirement: Session state machine governs navigation

The system SHALL define a sealed class `SessionState` with exactly these variants:

- `Anonymous`
- `OtpRequested(PhoneNumber phone, DateTime expiresAt)`
- `Authenticated(Session session)`
- `PinRequired(Profile profile, Session session)`
- `ProfileSelected(Profile profile, Session session)`
- `ManagementPinRequired(Session session)`
- `ManagingProfiles(Session session)`

The UI router (`go_router`) SHALL redirect based on the current `SessionState`:

| Current state | Target route |
|---------------|--------------|
| `Anonymous` | `/phone` |
| `OtpRequested` | `/otp` |
| `Authenticated` | `/profiles` |
| `PinRequired` | `/profiles/pin` |
| `ProfileSelected` | `/home` |
| `ManagementPinRequired` | `/profiles/manage/pin` |
| `ManagingProfiles` | `/profiles/manage` |

Within the `ManagingProfiles` state, the following sub-routes are navigable intra-state without triggering a redirect back to `/profiles/manage`:

- `/profiles/manage/new`
- `/profiles/manage/:id/edit`
- `/profiles/manage/main/pin`

Any attempt to navigate to a route not matching the current state (or its allowed sub-routes) SHALL be intercepted by the router's `redirect` function and rewritten to the target route above.

The state transitions SHALL be:

```
Anonymous → OtpRequested → Authenticated ──┬→ PinRequired → ProfileSelected
                                            │
                                            ├→ ProfileSelected  (profiles sans PIN)
                                            │
                                            └→ ManagementPinRequired → ManagingProfiles
```

And linear backward via:

- `LogoutUseCase`: any state → `Anonymous`
- Cancel PIN: `PinRequired` → `Authenticated`
- Deselect profile: `ProfileSelected` → `Authenticated`
- Cancel management PIN entry: `ManagementPinRequired` → `Authenticated`
- Exit management mode: `ManagingProfiles` → `Authenticated`

No other transitions SHALL be permitted. In particular, there SHALL be NO direct transition from `ManagingProfiles` to `ProfileSelected`, nor from `ProfileSelected` to `ManagementPinRequired` — entering or leaving management mode always passes through `Authenticated`.

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

#### Scenario: Router redirects ManagementPinRequired to /profiles/manage/pin

- **GIVEN** a session in state `ManagementPinRequired(session)`
- **WHEN** the user navigates to any route other than `/profiles/manage/pin`
- **THEN** the router redirects to `/profiles/manage/pin`

#### Scenario: Router allows sub-routes within ManagingProfiles

- **GIVEN** a session in state `ManagingProfiles(session)`
- **WHEN** the user navigates to `/profiles/manage/new`
- **THEN** the router does NOT redirect
- **AND** the profile creation form is rendered

#### Scenario: Router redirects Authenticated away from /profiles/manage

- **GIVEN** a session in state `Authenticated(session)`
- **WHEN** the user navigates to `/profiles/manage`
- **THEN** the router redirects to `/profiles`
