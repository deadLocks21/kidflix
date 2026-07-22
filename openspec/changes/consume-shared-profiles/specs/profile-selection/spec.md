## ADDED Requirements

### Requirement: Profile list is resynced on profile selection

The profile selection screen (`/profiles`) SHALL trigger
`SessionController.refreshProfiles()` when it mounts, in addition to the
existing trigger in `bootstrap()` after `restoreSession()`.

The call SHALL be fire-and-forget and SHALL swallow its errors: a network
failure, an expired token or an offline device SHALL leave the persisted
profile list untouched and SHALL NOT surface an error to the user, who is
about to pick a profile from a list that is still usable.

The call SHALL be skipped when the session state is `Anonymous` or
`OtpRequested` — `refreshProfiles()` throws `StateError` from those
states, which carry no session.

Rationale: a profile shared from another account server-side (cf. the
`share-profiles-across-users` change of `kidflix-api`) is only picked up
by a bootstrap refresh, i.e. a cold start. Without this second trigger, a
parent who shares a child profile has to ask the other parent to fully
restart the app before it appears.

#### Scenario: A newly shared profile appears without restarting the app

- **GIVEN** an authenticated session whose profile list holds only the main profile
- **AND** the backend now also returns a shared child profile
- **WHEN** the user lands on `/profiles`
- **THEN** `refreshProfiles()` is called
- **AND** the shared profile is displayed once the refresh resolves

#### Scenario: A failing refresh leaves the list usable

- **GIVEN** an authenticated session with a persisted profile list
- **AND** the device is offline
- **WHEN** the user lands on `/profiles`
- **THEN** the persisted profiles are still displayed
- **AND** no error message is surfaced

#### Scenario: No refresh without a session

- **GIVEN** a session state of `Anonymous`
- **WHEN** the profile selection screen mounts
- **THEN** `refreshProfiles()` is not called
- **AND** no `StateError` is thrown

## MODIFIED Requirements

### Requirement: Profile domain model

The system SHALL represent a profile as a Domain entity `Profile` with the following fields:

- `id`: stable identifier (string)
- `name`: display name (non-empty string)
- `ageCategory`: enum among `bebe`, `enfant`, `ado`, `jeuneAdulte`, `adulte`
- `pinHash`: bcrypt hash string, nullable (null means no PIN required)
- `avatarId`: nullable string, an id from the server-side avatar whitelist (the app resolves it against the `GET /avatars` catalog; no URL ever transits)
- `isMain`: boolean flag marking the main profile of the account. Defaults to `false` in the constructor. Immutable from the app's perspective — no Domain or Application operation SHALL mutate this field.
- `includedLowerAgeCategories`: list of categories *strictly lower* than `ageCategory` whose content the profile opted in to seeing on the homepage. Defaults to `[]`, which means the homepage filter falls back to a strict `==` match.
- `shared`: boolean flag marking a profile that belongs to **another account** and is shared with the current one. Defaults to `false`. Derived server-side from the caller's point of view, not stored on the profile: the same profile is `shared == false` for its owner and `shared == true` for the account it is shared with.
- `canManage`: boolean flag marking the right to edit the profile (name, avatar, age category, PIN). Defaults to `true`, which is always the correct value for an owned profile.

The entity SHALL be immutable and equatable by `id`.

`Profile.hasPin` SHALL be a computed boolean returning `true` when `pinHash` is non-null and non-empty.

`Profile.canDelete` SHALL be a computed boolean returning `!shared && !isMain`. Deleting a profile cascades on the owner household's watch progress, favorites and seen marks, so it SHALL remain owner-only even when `canManage` is `true`.

The following invariants on a `Session.profiles` list SHALL be guaranteed by the source of truth (backend, or in tests, the fake data):

1. Exactly one profile in the list has `isMain == true`. Profile sharing SHALL NOT break this invariant: a profile with `isMain == true` is never shareable — the backend refuses to create such a share **and** filters it out on read. This is what allows `currentProfileIdProvider` to derive the active management profile with `firstWhere((p) => p.isMain)` and no fallback.
2. The profile with `isMain == true` has `pinHash != null && pinHash.isNotEmpty`.
3. Profiles created from the app always have `isMain == false`, `shared == false` and `canManage == true` — creation always happens on one's own account.

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

#### Scenario: Sharing fields default to an owned profile

- **WHEN** a `Profile` is constructed without specifying `shared` nor `canManage`
- **THEN** `profile.shared` returns `false`
- **AND** `profile.canManage` returns `true`
- **AND** `profile.canDelete` returns `true` (assuming `isMain == false`)

#### Scenario: A shared profile is never deletable

- **WHEN** a `Profile` is constructed with `shared = true` and `canManage = true`
- **THEN** `profile.canManage` returns `true`
- **AND** `profile.canDelete` returns `false`

#### Scenario: The main profile is never deletable

- **WHEN** a `Profile` is constructed with `isMain = true`
- **THEN** `profile.canDelete` returns `false`
