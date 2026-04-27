# Profile management

## Purpose

Gestion du cycle de vie des profils attachés à un compte authentifié, côté
app. Couvre l'entrée en mode gestion (verrouillée par le PIN du profil
principal), la création, la modification (nom, catégorie, PIN), la
suppression, et la sortie du mode. Applique les invariants métier : un
seul profil principal par compte, le profil principal ne peut pas être
supprimé, son PIN peut être changé mais pas retiré. La confirmation par
double saisie est exigée uniquement pour le changement du PIN principal.
## Requirements
### Requirement: Enter profile management mode gated by main profile PIN

The system SHALL expose an application-layer usecase `EnterManagementModeUseCase` that transitions the session state from `Authenticated(session)` to `ManagementPinRequired(session)`.

The usecase SHALL only be callable when the session is in `Authenticated` state. Calling it from any other state SHALL return a failure result flagged `invalidState`.

The usecase SHALL verify that the session contains exactly one profile with `isMain == true`. If the session contains zero profiles with `isMain == true`, the usecase SHALL return a failure result flagged `noMainProfile` and leave the session state unchanged.

The profile selection screen (`/profiles`) SHALL expose a visible entry point labelled "Gérer les profils" at the bottom of the page. Tapping it SHALL invoke `EnterManagementModeUseCase`.

#### Scenario: Entering management mode from the profile selection screen

- **GIVEN** a session in state `Authenticated(session)` where `session.profiles` contains one profile with `isMain == true`
- **WHEN** the user taps the "Gérer les profils" button on `/profiles`
- **THEN** the session state becomes `ManagementPinRequired(session)`
- **AND** the router redirects to `/profiles/manage/pin`

#### Scenario: Cannot enter management mode from a non-Authenticated state

- **GIVEN** a session in state `ProfileSelected(profile, session)`
- **WHEN** `EnterManagementModeUseCase.execute()` is called
- **THEN** the usecase returns a failure result flagged `invalidState`
- **AND** the session state remains `ProfileSelected(profile, session)`

#### Scenario: Cannot enter management mode when no main profile exists

- **GIVEN** a session in state `Authenticated(session)` where no profile has `isMain == true`
- **WHEN** `EnterManagementModeUseCase.execute()` is called
- **THEN** the usecase returns a failure result flagged `noMainProfile`
- **AND** the session state remains `Authenticated(session)`

---

### Requirement: Verify management PIN locally via bcrypt

The system SHALL expose an application-layer usecase `VerifyManagementPinUseCase` that accepts a raw PIN string and verifies it against the `pinHash` of the main profile (the one with `isMain == true`) of the session currently in `ManagementPinRequired` state.

The verification SHALL reuse the existing Domain service `ProfilePinService` via its `verify(String rawPin, String bcryptHash)` method. The bcrypt computation SHALL be offloaded from the main isolate (same rule as `VerifyProfilePinUseCase`).

If the PIN matches, the usecase SHALL transition the session state from `ManagementPinRequired(session)` to `ManagingProfiles(session)`.

If the PIN does not match, the usecase SHALL return a failure result flagged `invalidPin` and leave the session state as `ManagementPinRequired(session)`.

If the usecase is called while the session is not in `ManagementPinRequired`, it SHALL return a failure result flagged `invalidState`.

The number of PIN attempts SHALL NOT be limited client-side in this change. Rate limiting will be handled at the API layer later.

The raw PIN string SHALL NEVER be logged, stored, or transmitted beyond the single `verify` call.

#### Scenario: Verify the correct main PIN

- **GIVEN** a session in state `ManagementPinRequired(session)` where the main profile has `pinHash = bcrypt("1234")`
- **WHEN** `VerifyManagementPinUseCase.execute("1234")` is called
- **THEN** the usecase returns a success result
- **AND** the session state becomes `ManagingProfiles(session)`

#### Scenario: Verify an incorrect main PIN

- **GIVEN** a session in state `ManagementPinRequired(session)` where the main profile has `pinHash = bcrypt("1234")`
- **WHEN** `VerifyManagementPinUseCase.execute("0000")` is called
- **THEN** the usecase returns a failure result flagged `invalidPin`
- **AND** the session state remains `ManagementPinRequired(session)`

#### Scenario: Multiple failed attempts are not blocked

- **GIVEN** a session in state `ManagementPinRequired(session)`
- **WHEN** `VerifyManagementPinUseCase.execute("0000")` is called 10 times in a row
- **THEN** each call returns `invalidPin`
- **AND** no cooldown, lockout, or state change is introduced client-side

---

### Requirement: Cancel management PIN entry

The system SHALL allow the user to cancel management PIN entry. Cancellation SHALL transition the session state from `ManagementPinRequired(session)` back to `Authenticated(session)`.

The action SHALL be a method on the session controller (e.g. `cancelManagementPinEntry()`) — no dedicated usecase required.

#### Scenario: Cancel management PIN entry

- **GIVEN** a session in state `ManagementPinRequired(session)`
- **WHEN** the user taps the back button or cancels the PIN entry
- **THEN** the session state becomes `Authenticated(session)`
- **AND** the router redirects to `/profiles`

---

### Requirement: Exit management mode manually

The system SHALL allow the user to exit management mode. Exit SHALL transition the session state from `ManagingProfiles(session)` back to `Authenticated(session)`.

Exit SHALL only occur via explicit user action (tapping "Terminer" on the management list screen, or a system back gesture that maps to the same transition). The system SHALL NOT exit management mode automatically based on a timeout.

The action SHALL be a method on the session controller (e.g. `exitManagementMode()`) — no dedicated usecase required.

After exit, re-entering management mode SHALL require another PIN verification.

#### Scenario: Exit management mode via the "Terminer" button

- **GIVEN** a session in state `ManagingProfiles(session)`
- **WHEN** the user taps the "Terminer" button on `/profiles/manage`
- **THEN** the session state becomes `Authenticated(session)`
- **AND** the router redirects to `/profiles`

#### Scenario: Re-entering management mode requires a fresh PIN

- **GIVEN** the user has just exited management mode, resulting in state `Authenticated(session)`
- **WHEN** the user taps "Gérer les profils" again
- **THEN** the session state becomes `ManagementPinRequired(session)`
- **AND** the user is prompted for the main PIN once more

#### Scenario: No automatic timeout exit

- **GIVEN** a session in state `ManagingProfiles(session)` with no user interaction
- **WHEN** an arbitrary amount of time passes
- **THEN** the session state remains `ManagingProfiles(session)`

---

### Requirement: Management mode state is volatile

The states `ManagementPinRequired(session)` and `ManagingProfiles(session)` SHALL NOT be persisted to storage.

When the application is closed and reopened, if a valid session is restored, the session state SHALL be `Authenticated(session)`, not `ManagementPinRequired` or `ManagingProfiles`, forcing the user to re-enter the main PIN before managing profiles.

#### Scenario: Management mode is lost on app restart

- **GIVEN** a running session in state `ManagingProfiles(session)`
- **WHEN** the app is killed and relaunched
- **AND** `RestoreSessionUseCase.execute()` runs successfully
- **THEN** the session state becomes `Authenticated(session)`, not `ManagingProfiles(session)`

---

### Requirement: Profile management repository interface

The system SHALL expose a Domain interface `ProfileManagementRepository` with the following operations:

```dart
abstract interface class ProfileManagementRepository {
  Future<Profile> create({
    required String name,
    required AgeCategory ageCategory,
    String? rawPin,
  });

  Future<Profile> updateMetadata({
    required String id,
    required String name,
    required AgeCategory ageCategory,
  });

  Future<Profile> setPin({
    required String id,
    required String rawPin,
  });

  Future<Profile> clearPin({required String id});

  Future<void> delete({required String id});
}
```

The repository SHALL always return profiles with `isMain == false` on `create`. No path SHALL exist from the app to create a profile with `isMain == true` — the main profile is created in the backend database alongside the user account, outside the app.

The operations `updateMetadata`, `setPin`, `clearPin` SHALL preserve the `isMain` flag of the target profile. Mutating `isMain` from the app SHALL be impossible by construction.

The operations SHALL enforce Domain invariants:

- `clearPin` SHALL throw `CannotClearMainProfilePinException` when the target profile has `isMain == true`.
- `delete` SHALL throw `CannotDeleteMainProfileException` when the target profile has `isMain == true`.

HTTP implementations SHALL additionally throw `UnknownProfileException` when the backend responds `404` on a `/profiles/{id}/*` route. InMemory implementations SHALL signal the same condition with `StateError` (it is a "should never happen" guard for the in-memory store).

The repository SHALL have two implementations:

- `InMemoryProfileManagementRepository` under `lib/infrastructure/profile_management/`, operating on the shared `InMemoryAccountsStore`.
- `DioProfileManagementRepository` under `lib/infrastructure/profile_management/`, calling the backend `/profiles/*` endpoints. Selected at build time via `--dart-define=API_BASE_URL=...` (see "ProfileManagementRepository implementation selection via API_BASE_URL").

#### Scenario: Create produces a profile with isMain false

- **GIVEN** an authenticated session with an existing main profile
- **WHEN** `ProfileManagementRepository.create(name: "Léo", ageCategory: enfant)` is called
- **THEN** the returned `Profile` has `isMain == false`
- **AND** the returned profile has a non-empty unique id
- **AND** `pinHash == null` because `rawPin` was not provided

#### Scenario: Delete throws on a main profile

- **GIVEN** a main profile with id `"papa"`
- **WHEN** `ProfileManagementRepository.delete(id: "papa")` is called
- **THEN** the call throws `CannotDeleteMainProfileException("papa")`
- **AND** the profile is not removed from storage

#### Scenario: Clear PIN throws on a main profile

- **GIVEN** a main profile with id `"papa"` and a PIN set
- **WHEN** `ProfileManagementRepository.clearPin(id: "papa")` is called
- **THEN** the call throws `CannotClearMainProfilePinException("papa")`
- **AND** the PIN hash of the profile remains unchanged

#### Scenario: Update metadata preserves isMain and pinHash

- **GIVEN** a main profile with `id = "papa"`, `name = "Papa"`, `isMain = true`, `pinHash = bcrypt("1234")`
- **WHEN** `ProfileManagementRepository.updateMetadata(id: "papa", name: "Papou", ageCategory: adulte)` is called
- **THEN** the returned profile has `name = "Papou"`, `isMain = true`, `pinHash = bcrypt("1234")` unchanged

### Requirement: Create a new profile

The system SHALL expose an application-layer usecase `CreateProfileUseCase` that accepts a name, an age category, and an optional raw PIN, and creates a new profile in the active session.

The usecase SHALL only be callable when the session is in `ManagingProfiles` state. Calling it from any other state SHALL return a failure result flagged `invalidState`.

The name SHALL be validated: after trimming surrounding whitespace, it SHALL be non-empty and at most 30 characters. Otherwise the usecase SHALL return a failure result flagged `invalidName`. Uniqueness of the name within the account SHALL NOT be enforced — two profiles with the same name are allowed and distinguished by their stable id.

If a raw PIN is provided, it SHALL be validated as exactly 4 digits (`^[0-9]{4}$`). Otherwise the usecase SHALL return a failure result flagged `invalidPin`.

On success, the usecase SHALL call `ProfileManagementRepository.create(...)` and then update the session's profile list in the session controller by appending the new profile.

The new profile SHALL always have `isMain == false`.

#### Scenario: Create a profile with no PIN

- **GIVEN** a session in state `ManagingProfiles(session)` with 3 profiles
- **WHEN** `CreateProfileUseCase.execute(name: "Léo", ageCategory: enfant, rawPin: null)` is called
- **THEN** the usecase returns a success result carrying the new `ProfileDto`
- **AND** the session's profile list now contains 4 profiles
- **AND** the new profile has `hasPin == false` and `isMain == false`

#### Scenario: Create a profile with a valid PIN

- **WHEN** `CreateProfileUseCase.execute(name: "Léo", ageCategory: enfant, rawPin: "1234")` is called
- **THEN** the usecase returns a success result
- **AND** the stored profile has a bcrypt `pinHash` matching `"1234"` when verified via `ProfilePinService.verify`

#### Scenario: Reject a profile with an empty name

- **WHEN** `CreateProfileUseCase.execute(name: "   ", ageCategory: enfant)` is called
- **THEN** the usecase returns a failure result flagged `invalidName`
- **AND** the session's profile list is unchanged

#### Scenario: Reject a profile with a name longer than 30 characters

- **WHEN** `CreateProfileUseCase.execute(name: "a" * 31, ageCategory: enfant)` is called
- **THEN** the usecase returns a failure result flagged `invalidName`

#### Scenario: Reject a profile with a malformed PIN

- **WHEN** `CreateProfileUseCase.execute(name: "Léo", ageCategory: enfant, rawPin: "12a4")` is called
- **THEN** the usecase returns a failure result flagged `invalidPin`

#### Scenario: Cannot create a profile outside management mode

- **GIVEN** a session in state `Authenticated(session)`
- **WHEN** `CreateProfileUseCase.execute(name: "Léo", ageCategory: enfant)` is called
- **THEN** the usecase returns a failure result flagged `invalidState`

---

### Requirement: Update profile metadata (name, age category)

The system SHALL expose an application-layer usecase `UpdateProfileMetadataUseCase` that accepts a profile id, a new name, and a new age category, and updates these fields on an existing profile.

The usecase SHALL be callable on any profile (main or not) — only the PIN of the main profile has special rules; the metadata (name, age category) is freely editable on all profiles.

The usecase SHALL only be callable when the session is in `ManagingProfiles` state. Otherwise it SHALL return a failure result flagged `invalidState`.

The name SHALL be validated with the same rules as `CreateProfileUseCase`. Otherwise the usecase SHALL return a failure result flagged `invalidName`.

If the target profile id does not exist in the current session, the usecase SHALL return a failure result flagged `unknownProfile`.

On success, the usecase SHALL call `ProfileManagementRepository.updateMetadata(...)` and patch the session's profile list with the returned profile.

#### Scenario: Rename a standard profile

- **GIVEN** a session in state `ManagingProfiles(session)` with profile `"ar"` (name "Ar", isMain false)
- **WHEN** `UpdateProfileMetadataUseCase.execute(id: "ar", name: "Arthur", ageCategory: enfant)` is called
- **THEN** the usecase returns a success result
- **AND** the profile `"ar"` in the session is now `name = "Arthur"`, `isMain = false` (unchanged)

#### Scenario: Rename the main profile

- **GIVEN** a session in state `ManagingProfiles(session)` with main profile `"papa"` (isMain true, pinHash set)
- **WHEN** `UpdateProfileMetadataUseCase.execute(id: "papa", name: "Papou", ageCategory: adulte)` is called
- **THEN** the usecase returns a success result
- **AND** the profile `"papa"` in the session is now `name = "Papou"`, with `isMain == true` and `pinHash` unchanged

#### Scenario: Reject an update with an empty name

- **WHEN** `UpdateProfileMetadataUseCase.execute(id: "ar", name: "", ageCategory: enfant)` is called
- **THEN** the usecase returns a failure result flagged `invalidName`
- **AND** the profile is unchanged

#### Scenario: Reject an update on a non-existent profile

- **WHEN** `UpdateProfileMetadataUseCase.execute(id: "ghost", name: "X", ageCategory: enfant)` is called
- **THEN** the usecase returns a failure result flagged `unknownProfile`

---

### Requirement: Change a standard profile's PIN (set or replace)

The system SHALL expose an application-layer usecase `ChangeProfilePinUseCase` that accepts a profile id and a new raw PIN, and sets or replaces the PIN on a standard (non-main) profile.

The usecase SHALL only be callable when the session is in `ManagingProfiles` state. Otherwise it SHALL return a failure result flagged `invalidState`.

The raw PIN SHALL be validated as exactly 4 digits. Otherwise the usecase SHALL return a failure result flagged `invalidPin`.

If the target profile id does not exist, the usecase SHALL return a failure result flagged `unknownProfile`.

The usecase is callable on a profile with `isMain == false`. It SHALL also be callable on the main profile, but using it on the main profile does NOT require double-entry confirmation — callers that want confirmation must use `ChangeMainProfilePinUseCase` (see next requirement). In practice, the UI SHALL route the main profile to `ChangeMainProfilePinUseCase` exclusively; `ChangeProfilePinUseCase` is used for standard profiles only.

On success, the usecase SHALL call `ProfileManagementRepository.setPin(...)` and patch the session's profile list.

#### Scenario: Set a PIN on a standard profile that had none

- **GIVEN** a session in state `ManagingProfiles(session)` with profile `"ar"` (`hasPin == false`)
- **WHEN** `ChangeProfilePinUseCase.execute(id: "ar", rawPin: "2468")` is called
- **THEN** the usecase returns a success result
- **AND** the profile `"ar"` in the session now has `hasPin == true` with a bcrypt hash verifying against `"2468"`

#### Scenario: Replace an existing PIN on a standard profile

- **GIVEN** profile `"ro"` with existing `pinHash = bcrypt("9999")`
- **WHEN** `ChangeProfilePinUseCase.execute(id: "ro", rawPin: "1111")` is called
- **THEN** the new `pinHash` verifies against `"1111"` and no longer against `"9999"`

#### Scenario: Reject a malformed PIN

- **WHEN** `ChangeProfilePinUseCase.execute(id: "ar", rawPin: "12345")` is called
- **THEN** the usecase returns a failure result flagged `invalidPin`

---

### Requirement: Clear a standard profile's PIN

The system SHALL expose an application-layer usecase `ClearProfilePinUseCase` that accepts a profile id and removes the PIN from a standard (non-main) profile.

The usecase SHALL only be callable when the session is in `ManagingProfiles` state.

If the target profile id does not exist, the usecase SHALL return a failure result flagged `unknownProfile`.

If the target profile has `isMain == true`, the underlying `ProfileManagementRepository.clearPin(...)` SHALL throw `CannotClearMainProfilePinException`. The usecase SHALL catch this exception and return a failure result flagged `cannotClearMainPin`. The UI SHALL NOT offer this action on the main profile in the first place, but the defense-in-depth check at the Domain level prevents bypass.

On success, the usecase SHALL call `ProfileManagementRepository.clearPin(...)` and patch the session's profile list. The resulting profile has `hasPin == false`.

#### Scenario: Clear the PIN on a standard profile

- **GIVEN** profile `"ro"` with `pinHash = bcrypt("9999")`
- **WHEN** `ClearProfilePinUseCase.execute(id: "ro")` is called
- **THEN** the usecase returns a success result
- **AND** the profile `"ro"` in the session now has `hasPin == false`

#### Scenario: Attempting to clear the main profile's PIN

- **GIVEN** main profile `"papa"` with `pinHash = bcrypt("1234")`
- **WHEN** `ClearProfilePinUseCase.execute(id: "papa")` is called
- **THEN** the usecase returns a failure result flagged `cannotClearMainPin`
- **AND** `papa.pinHash` is unchanged

---

### Requirement: Change the main profile's PIN with double-entry confirmation

The system SHALL expose an application-layer usecase `ChangeMainProfilePinUseCase` that accepts a `newPin` and a `confirmPin`, and replaces the PIN of the profile currently flagged `isMain` in the session.

The usecase SHALL only be callable when the session is in `ManagingProfiles` state. Otherwise it SHALL return a failure result flagged `invalidState`.

Before any mutation, the usecase SHALL compare `newPin` and `confirmPin` byte-for-byte. If they differ, the usecase SHALL throw (or return) `PinConfirmationMismatchException` mapped to a failure result flagged `pinMismatch`. No call to the repository SHALL be made.

If both PINs are identical, the PIN value SHALL be validated as exactly 4 digits. Otherwise the usecase SHALL return a failure result flagged `invalidPin`.

On success, the usecase SHALL call `ProfileManagementRepository.setPin(id: mainProfileId, rawPin: newPin)` and patch the session's profile list. The updated main profile SHALL retain `isMain == true`.

This usecase SHALL be the ONLY path from the app to modify the main profile's PIN.

#### Scenario: Change the main PIN with matching entries

- **GIVEN** a session in state `ManagingProfiles(session)` with main profile `"papa"` (current `pinHash = bcrypt("1234")`)
- **WHEN** `ChangeMainProfilePinUseCase.execute(newPin: "5678", confirmPin: "5678")` is called
- **THEN** the usecase returns a success result
- **AND** the main profile's new `pinHash` verifies against `"5678"` and no longer against `"1234"`
- **AND** the main profile still has `isMain == true`

#### Scenario: Reject mismatched double entry

- **GIVEN** a session in state `ManagingProfiles(session)` with main profile `"papa"`
- **WHEN** `ChangeMainProfilePinUseCase.execute(newPin: "5678", confirmPin: "5679")` is called
- **THEN** the usecase returns a failure result flagged `pinMismatch`
- **AND** the main profile's `pinHash` is unchanged
- **AND** no bcrypt hashing is performed (short-circuit before the repository call)

#### Scenario: Reject a malformed PIN

- **WHEN** `ChangeMainProfilePinUseCase.execute(newPin: "123", confirmPin: "123")` is called
- **THEN** the usecase returns a failure result flagged `invalidPin`

#### Scenario: Cannot change the main PIN outside management mode

- **GIVEN** a session in state `Authenticated(session)`
- **WHEN** `ChangeMainProfilePinUseCase.execute(newPin: "5678", confirmPin: "5678")` is called
- **THEN** the usecase returns a failure result flagged `invalidState`

---

### Requirement: Delete a profile

The system SHALL expose an application-layer usecase `DeleteProfileUseCase` that accepts a profile id and removes it from the session's profile list.

The usecase SHALL only be callable when the session is in `ManagingProfiles` state. Otherwise it SHALL return a failure result flagged `invalidState`.

If the target profile id does not exist, the usecase SHALL return a failure result flagged `unknownProfile`.

If the target profile has `isMain == true`, the underlying `ProfileManagementRepository.delete(...)` SHALL throw `CannotDeleteMainProfileException`. The usecase SHALL catch this exception and return a failure result flagged `cannotDeleteMain`. The UI SHALL visually disable the delete action on the main profile as an additional safeguard.

On success, the usecase SHALL call `ProfileManagementRepository.delete(...)` and update the session's profile list by removing the profile with the matching id.

#### Scenario: Delete a standard profile

- **GIVEN** a session in state `ManagingProfiles(session)` with profiles `["papa", "ar", "ro"]` (papa isMain)
- **WHEN** `DeleteProfileUseCase.execute(id: "ar")` is called
- **THEN** the usecase returns a success result
- **AND** the session's profile list is now `["papa", "ro"]`

#### Scenario: Attempting to delete the main profile

- **GIVEN** a session in state `ManagingProfiles(session)` where `"papa"` has `isMain == true`
- **WHEN** `DeleteProfileUseCase.execute(id: "papa")` is called
- **THEN** the usecase returns a failure result flagged `cannotDeleteMain`
- **AND** the session's profile list is unchanged

#### Scenario: Delete a non-existent profile

- **WHEN** `DeleteProfileUseCase.execute(id: "ghost")` is called
- **THEN** the usecase returns a failure result flagged `unknownProfile`

---

### Requirement: UI DTO exposes isMain

The `ProfileDto` emitted by the session controller SHALL include a `isMain: bool` field derived from the Domain `Profile.isMain`.

The DTO SHALL NOT expose `pinHash` (existing rule, preserved).

The UI SHALL use `isMain` to:

- Display a "Principal" badge on the management tile
- Disable the delete button on the main profile
- Route PIN changes on the main profile to the dedicated double-entry screen instead of the standard edit form

#### Scenario: DTO carries isMain

- **GIVEN** a Domain `Profile` with `isMain == true`
- **WHEN** `ProfileDto.fromDomain(profile)` is called
- **THEN** the DTO has `isMain == true`
- **AND** the DTO does not expose `pinHash`

---

### Requirement: Session profile list is updated in-memory after each mutation

After any successful mutation (`create`, `updateMetadata`, `setPin`, `clearPin`, `delete`, `changeMainProfilePin`), the session controller SHALL emit a new `Session` whose `profiles` list reflects the mutation, so that `/profiles/manage` and `/profiles` observers re-render automatically.

The controller SHALL NOT re-fetch the entire session from the repository after each mutation. The updated `Profile` returned by the repository SHALL be merged into the existing session list by `id`.

#### Scenario: List refreshes after a create

- **GIVEN** a session observer subscribed to `sessionControllerProvider`
- **WHEN** `CreateProfileUseCase.execute(...)` completes successfully
- **THEN** the observer receives a new `Session` with one more profile

#### Scenario: List refreshes after a delete

- **WHEN** `DeleteProfileUseCase.execute(id: "ar")` completes successfully
- **THEN** the observer receives a new `Session` where no profile has `id == "ar"`

---

### Requirement: Management screens are not reachable outside the correct state

The router `go_router` SHALL redirect any direct navigation attempt to `/profiles/manage/pin`, `/profiles/manage`, `/profiles/manage/new`, `/profiles/manage/:id/edit`, or `/profiles/manage/main/pin` that does not match the current `SessionState`.

Specifically:

- `/profiles/manage/pin` is only reachable when state is `ManagementPinRequired`
- `/profiles/manage` and its sub-routes are only reachable when state is `ManagingProfiles`

From any other state, attempting these URLs SHALL redirect to the canonical route of the current state (e.g. `/profiles` when `Authenticated`, `/phone` when `Anonymous`).

#### Scenario: Direct access to /profiles/manage without PIN is blocked

- **GIVEN** a session in state `Authenticated(session)`
- **WHEN** the user navigates to `/profiles/manage` (e.g. via a deep link or back gesture)
- **THEN** the router redirects to `/profiles`

#### Scenario: Direct access to /profiles/manage/pin from Anonymous is blocked

- **GIVEN** a session in state `Anonymous`
- **WHEN** the user navigates to `/profiles/manage/pin`
- **THEN** the router redirects to `/phone`

### Requirement: UnknownProfileException domain exception

The system SHALL define a Domain exception `UnknownProfileException implements Exception` in `lib/core/domain/exceptions/unknown_profile.exception.dart`.

The exception SHALL carry the offending `profileId: String` via a `const` constructor `UnknownProfileException(this.profileId)`.

The `toString()` method SHALL return `'UnknownProfileException: "<profileId>"'`, consistent with the existing `CannotDeleteMainProfileException` and `CannotClearMainProfilePinException` formatting.

The exception SHALL be thrown by HTTP implementations of `ProfileManagementRepository` when the backend responds `404` on a `/profiles/{id}/*` route — this is the contract path for "the profile id does not exist (or no longer exists) in the authenticated account". InMemory implementations SHALL NOT throw it (they signal the same condition via `StateError` to mark the bug). Application-layer usecases SHALL catch this exception and map it to their existing `unknownProfile` failure flag.

#### Scenario: Carries the profile id

- **WHEN** `UnknownProfileException("ar")` is constructed
- **THEN** the exception's `profileId` is `"ar"`

#### Scenario: Stringifies with quoted id

- **WHEN** `UnknownProfileException("ar").toString()` is called
- **THEN** the returned string is `'UnknownProfileException: "ar"'`

---

### Requirement: HTTP implementation of ProfileManagementRepository (DioProfileManagementRepository)

The system SHALL provide an HTTP implementation `DioProfileManagementRepository implements ProfileManagementRepository` in `lib/infrastructure/profile_management/dio.profile_management.repository.dart` that calls the backend `/profiles/*` endpoints documented in `API.md`.

The class SHALL accept a `Dio` instance via its constructor and SHALL NOT instantiate its own — the `Dio` is provided by `dioProvider`, which has the `AuthInterceptor` registered. The repository itself SHALL NOT add `Authorization` or `X-Device-Id` headers explicitly — these are injected transparently by the interceptor.

`create({required String name, required AgeCategory ageCategory, String? rawPin})` SHALL:

1. Issue `POST /profiles` with body `{ "name": <name>, "age_category": <ageCategoryToWire(ageCategory)>, "raw_pin": <rawPin> }`. The `raw_pin` key SHALL be omitted when `rawPin == null`.
2. On HTTP 200, parse the response via `RemoteProfileDto.fromJson` and return `dto.toDomain()`. The returned `Profile.id` is the stable id assigned by the backend, and `Profile.isMain` is `false`.
3. On any `DioException`, rethrow. No metier-level exception mapping is needed for `create` — the contract has no documented business error code on this endpoint.

`updateMetadata({required String id, required String name, required AgeCategory ageCategory})` SHALL:

1. Issue `PATCH /profiles/<id>` with body `{ "name": <name>, "age_category": <ageCategoryToWire(ageCategory)> }`.
2. On HTTP 200, parse the response via `RemoteProfileDto.fromJson(...).toDomain()` and return.
3. On `DioException` whose response has `statusCode == 404`, throw `UnknownProfileException(id)`.
4. On any other `DioException`, rethrow.

`setPin({required String id, required String rawPin})` SHALL:

1. Issue `PUT /profiles/<id>/pin` with body `{ "raw_pin": <rawPin> }`.
2. On HTTP 200, parse the response via `RemoteProfileDto.fromJson(...).toDomain()` and return.
3. On `DioException` whose response has `statusCode == 404`, throw `UnknownProfileException(id)`.
4. On any other `DioException`, rethrow.

`clearPin({required String id})` SHALL:

1. Issue `DELETE /profiles/<id>/pin` (no request body).
2. On HTTP 200, parse the response via `RemoteProfileDto.fromJson(...).toDomain()` and return. The returned `Profile.pinHash` is `null`.
3. On `DioException` whose response has `statusCode == 422` and `readErrorCode(response) == "cannot_clear_main_profile_pin"`, throw `CannotClearMainProfilePinException(id)`.
4. On `DioException` whose response has `statusCode == 404`, throw `UnknownProfileException(id)`.
5. On any other `DioException`, rethrow.

`delete({required String id})` SHALL:

1. Issue `DELETE /profiles/<id>` (no request body).
2. On HTTP 204, return without parsing — the response body is empty by contract.
3. On `DioException` whose response has `statusCode == 422` and `readErrorCode(response) == "cannot_delete_main_profile"`, throw `CannotDeleteMainProfileException(id)`.
4. On `DioException` whose response has `statusCode == 404`, throw `UnknownProfileException(id)`.
5. On any other `DioException`, rethrow.

The implementation SHALL read the `error.code` from the response body via the shared top-level function `readErrorCode(Response?)` from `lib/infrastructure/http/error_code.dart` — never via a duplicated private helper.

The 404 mapping SHALL be performed on `statusCode` alone, without checking `error.code`. On the `/profiles/{id}/*` routes the path is scoped by id and the JWT scopes by account, so a 404 has no other interpretation than "profile does not exist".

The implementation SHALL NOT log raw response bodies or PII (raw PINs, JWT) at any log level.

The implementation SHALL NOT retry failed requests — retry policy is out of scope for this change.

The age category serialization SHALL use the public top-level function `ageCategoryToWire(AgeCategory)` exposed from `remote_profile.dto.dart` (promoted from the previously-private `_ageCategoryToWire`). The mapping is:

| `AgeCategory` | Wire string |
|---|---|
| `bebe` | `"bebe"` |
| `enfant` | `"enfant"` |
| `ado` | `"ado"` |
| `jeuneAdulte` | `"jeune_adulte"` |
| `adulte` | `"adulte"` |

#### Scenario: create posts the body and returns the parsed profile

- **GIVEN** the backend responds 200 with a `RemoteProfileDto` JSON for a new profile (`id: "new-uuid"`, `is_main: false`)
- **WHEN** `create(name: "Léa", ageCategory: AgeCategory.enfant, rawPin: "1234")` is called
- **THEN** the request body sent to the backend has `name == "Léa"`, `age_category == "enfant"`, `raw_pin == "1234"`
- **AND** the future completes with a `Profile` whose `id == "new-uuid"`, `name == "Léa"`, `ageCategory == AgeCategory.enfant`, `isMain == false`

#### Scenario: create omits raw_pin when rawPin is null

- **WHEN** `create(name: "Léa", ageCategory: AgeCategory.enfant, rawPin: null)` is called
- **THEN** the request body sent to the backend contains keys `name`, `age_category`
- **AND** the request body does NOT contain a `raw_pin` key

#### Scenario: updateMetadata patches name and age category

- **GIVEN** the backend responds 200 with the updated profile JSON
- **WHEN** `updateMetadata(id: "ar", name: "Arthur", ageCategory: AgeCategory.ado)` is called
- **THEN** the request method is `PATCH` on path `/profiles/ar`
- **AND** the request body has `name == "Arthur"`, `age_category == "ado"`
- **AND** the future completes with the parsed `Profile`

#### Scenario: updateMetadata maps 404 to UnknownProfileException

- **GIVEN** the backend responds 404 with any body
- **WHEN** `updateMetadata(id: "ghost", name: "X", ageCategory: AgeCategory.enfant)` is called
- **THEN** the future throws `UnknownProfileException` carrying `profileId == "ghost"`

#### Scenario: setPin puts raw_pin and returns updated profile

- **GIVEN** the backend responds 200 with the updated profile JSON (new bcrypt hash)
- **WHEN** `setPin(id: "ar", rawPin: "9999")` is called
- **THEN** the request method is `PUT` on path `/profiles/ar/pin`
- **AND** the request body has `raw_pin == "9999"`
- **AND** the future completes with the parsed `Profile`

#### Scenario: setPin maps 404 to UnknownProfileException

- **GIVEN** the backend responds 404 with any body
- **WHEN** `setPin(id: "ghost", rawPin: "1234")` is called
- **THEN** the future throws `UnknownProfileException` carrying `profileId == "ghost"`

#### Scenario: clearPin returns the cleared profile

- **GIVEN** the backend responds 200 with the updated profile JSON (`pin_hash: null`)
- **WHEN** `clearPin(id: "ar")` is called
- **THEN** the request method is `DELETE` on path `/profiles/ar/pin`
- **AND** the future completes with a `Profile` whose `pinHash == null`

#### Scenario: clearPin maps 422 cannot_clear_main_profile_pin

- **GIVEN** the backend responds 422 with body `{ "error": { "code": "cannot_clear_main_profile_pin" } }`
- **WHEN** `clearPin(id: "papa")` is called
- **THEN** the future throws `CannotClearMainProfilePinException` carrying `profileId == "papa"`

#### Scenario: clearPin maps 404 to UnknownProfileException

- **GIVEN** the backend responds 404 with any body
- **WHEN** `clearPin(id: "ghost")` is called
- **THEN** the future throws `UnknownProfileException` carrying `profileId == "ghost"`

#### Scenario: delete completes silently on 204

- **GIVEN** the backend responds 204 with no body
- **WHEN** `delete(id: "ar")` is called
- **THEN** the future completes with no value
- **AND** no parsing of the body is attempted

#### Scenario: delete maps 422 cannot_delete_main_profile

- **GIVEN** the backend responds 422 with body `{ "error": { "code": "cannot_delete_main_profile" } }`
- **WHEN** `delete(id: "papa")` is called
- **THEN** the future throws `CannotDeleteMainProfileException` carrying `profileId == "papa"`

#### Scenario: delete maps 404 to UnknownProfileException

- **GIVEN** the backend responds 404 with any body
- **WHEN** `delete(id: "ghost")` is called
- **THEN** the future throws `UnknownProfileException` carrying `profileId == "ghost"`

#### Scenario: 422 with non-matching error.code is rethrown

- **GIVEN** the backend responds 422 with body `{ "error": { "code": "unrelated_constraint" } }` on `clearPin`
- **WHEN** `clearPin(id: "ar")` is called
- **THEN** the future throws `DioException` (NOT a Domain exception)

#### Scenario: 422 with malformed error body is rethrown safely

- **GIVEN** the backend responds 422 with body `"plain text"` on `delete`
- **WHEN** `delete(id: "ar")` is called
- **THEN** the future throws `DioException` (NOT a Domain exception)
- **AND** does NOT throw `_TypeError` or `_CastError`

#### Scenario: rethrows on 5xx

- **GIVEN** the backend responds 500 with empty body on any method
- **WHEN** that method is called
- **THEN** the future throws `DioException` with `statusCode == 500`

---

### Requirement: ProfileManagementRepository implementation selection via API_BASE_URL

The system SHALL select between the in-memory and HTTP implementations of `ProfileManagementRepository` based on the compile-time constant `String.fromEnvironment('API_BASE_URL')`, mirroring the selection logic for `AuthRepository`.

The selection logic SHALL live in the Riverpod provider `profileManagementRepositoryProvider` (`lib/infrastructure/providers/profile_management.repository_provider.dart`) and SHALL behave as follows:

```dart
const baseUrl = String.fromEnvironment('API_BASE_URL');
if (baseUrl.isEmpty) {
  final store = ref.watch(inMemoryAccountsStoreProvider);
  final pin = ref.watch(profilePinServiceProvider);
  return InMemoryProfileManagementRepository(store, pin);  // existing behavior
}
return DioProfileManagementRepository(ref.watch(dioProvider));  // new behavior
```

The selection SHALL happen at build time via the `--dart-define` mechanism — `String.fromEnvironment` is a `const` expression evaluated at compilation, NOT a runtime lookup of an environment variable.

When `API_BASE_URL` is unset (default), the provider SHALL return the existing `InMemoryProfileManagementRepository` so that:

- Developers running `flutter run` without the flag get the in-memory behavior identical to before this change.
- Tests running `flutter test` (which never pass `--dart-define`) continue to use the in-memory implementation.

When `API_BASE_URL` is set to a non-empty string, the provider SHALL return a `DioProfileManagementRepository` consuming the centralized `dioProvider`.

The provider SHALL remain `@Riverpod(keepAlive: true)` so the chosen implementation is created once per app lifetime.

The selection SHALL be consistent with `authRepositoryProvider`: a build either runs both repositories in in-memory mode (no flag) or both in HTTP mode (flag set). Mixed modes are not supported and SHALL not be exposed.

#### Scenario: Default build returns InMemoryProfileManagementRepository

- **GIVEN** the app is built without `--dart-define=API_BASE_URL`
- **WHEN** any consumer reads `profileManagementRepositoryProvider`
- **THEN** the returned instance is of runtime type `InMemoryProfileManagementRepository`

#### Scenario: Build with API_BASE_URL returns DioProfileManagementRepository

- **GIVEN** the app is built with `--dart-define=API_BASE_URL=http://localhost:8080`
- **WHEN** any consumer reads `profileManagementRepositoryProvider`
- **THEN** the returned instance is of runtime type `DioProfileManagementRepository`

#### Scenario: Test override remains supported

- **GIVEN** a test that overrides `profileManagementRepositoryProvider` with a fake implementation via `ProviderContainer.test`
- **WHEN** the consumer reads `profileManagementRepositoryProvider` in the test
- **THEN** the fake is returned regardless of the `API_BASE_URL` value the test was compiled with

---

### Requirement: Public `ageCategoryToWire` helper

The system SHALL expose a public top-level function `String ageCategoryToWire(AgeCategory category)` in `lib/core/application/dtos/remote_profile.dto.dart`, promoted from the previously-private `_ageCategoryToWire` introduced by `2026-04-27-add-http-auth-repository`.

The function SHALL implement the exact mapping documented under "HTTP implementation of ProfileManagementRepository" and reused by `RemoteProfileDto.toJson`.

The complementary `_ageCategoryFromWire` SHALL remain private — it is only consumed by `RemoteProfileDto.fromJson` internally.

The promotion SHALL NOT change the existing `RemoteProfileDto.toJson` semantics: it continues to call this mapping internally, just under the public name.

#### Scenario: Maps each enum variant to its snake_case wire string

- **GIVEN** the five `AgeCategory` variants: `bebe`, `enfant`, `ado`, `jeuneAdulte`, `adulte`
- **WHEN** `ageCategoryToWire` is called on each
- **THEN** the returned values are `"bebe"`, `"enfant"`, `"ado"`, `"jeune_adulte"`, `"adulte"` respectively

---

### Requirement: Usecases catch UnknownProfileException as defense in depth

The five mutation usecases that target a profile by id SHALL catch `UnknownProfileException` thrown by the repository layer and map it to their existing `unknownProfile` failure result, in addition to keeping the existing `session.profiles.any(...)` pre-check.

The usecases concerned are:

- `UpdateProfileMetadataUseCase` → `UpdateProfileMetadataUnknownProfile()`
- `ChangeProfilePinUseCase` → `ChangeProfilePinUnknownProfile()`
- `ClearProfilePinUseCase` → `ClearProfilePinUnknownProfile()`
- `DeleteProfileUseCase` → `DeleteProfileUnknownProfile()`
- `ChangeMainProfilePinUseCase` → a new result `ChangeMainProfilePinUnknownProfile()` (added in this change)

The pre-check `session.profiles.any((p) => p.id == profileId)` SHALL be preserved as a fast path: it allows returning the failure flag without a network round-trip when the id is obviously absent. The exception catch SHALL cover the race-condition case where the profile existed in the locally-known session but disappeared on the backend between read and mutation (e.g. another device deleted it).

The catch SHALL NOT be added to `CreateProfileUseCase` — it does not target an existing profile by id and cannot produce a 404.

#### Scenario: UpdateProfileMetadataUseCase maps UnknownProfileException to its flag

- **GIVEN** a session containing profile `"ar"`
- **AND** a repository that throws `UnknownProfileException("ar")` on `updateMetadata`
- **WHEN** `UpdateProfileMetadataUseCase.execute(session: session, profileId: "ar", rawName: "Arthur", ageCategory: enfant)` is called
- **THEN** the result is `UpdateProfileMetadataUnknownProfile()`

#### Scenario: ChangeProfilePinUseCase maps UnknownProfileException to its flag

- **GIVEN** a session containing profile `"ar"`
- **AND** a repository that throws `UnknownProfileException("ar")` on `setPin`
- **WHEN** `ChangeProfilePinUseCase.execute(session: session, profileId: "ar", rawPin: "1234")` is called
- **THEN** the result is `ChangeProfilePinUnknownProfile()`

#### Scenario: ClearProfilePinUseCase maps UnknownProfileException to its flag

- **GIVEN** a session containing profile `"ar"`
- **AND** a repository that throws `UnknownProfileException("ar")` on `clearPin`
- **WHEN** `ClearProfilePinUseCase.execute(session: session, profileId: "ar")` is called
- **THEN** the result is `ClearProfilePinUnknownProfile()`

#### Scenario: DeleteProfileUseCase maps UnknownProfileException to its flag

- **GIVEN** a session containing profile `"ar"`
- **AND** a repository that throws `UnknownProfileException("ar")` on `delete`
- **WHEN** `DeleteProfileUseCase.execute(session: session, profileId: "ar")` is called
- **THEN** the result is `DeleteProfileUnknownProfile()`

#### Scenario: ChangeMainProfilePinUseCase maps UnknownProfileException to its new flag

- **GIVEN** a session whose main profile is `"papa"`
- **AND** a repository that throws `UnknownProfileException("papa")` on `setPin`
- **WHEN** `ChangeMainProfilePinUseCase.execute(session: session, newPin: "5678", confirmPin: "5678")` is called
- **THEN** the result is `ChangeMainProfilePinUnknownProfile()`

#### Scenario: Pre-check still short-circuits without a repo call

- **GIVEN** a session whose `profiles` list does not contain id `"ghost"`
- **AND** a repository that would throw if called
- **WHEN** `UpdateProfileMetadataUseCase.execute(session: session, profileId: "ghost", rawName: "X", ageCategory: enfant)` is called
- **THEN** the result is `UpdateProfileMetadataUnknownProfile()`
- **AND** the repository's `updateMetadata` was NOT called

