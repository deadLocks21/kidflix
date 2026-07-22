## ADDED Requirements

### Requirement: Shared profiles are visually distinguished and their actions gated

The profile management list SHALL display a "Partagé" badge on every
profile tile whose `ProfileDto.shared` is `true`, alongside the existing
"Principal" badge and PIN padlock. The two badges are mutually exclusive
in practice: a main profile is never shareable.

The tile SHALL disable the edit action when `ProfileDto.canManage` is
`false`, and the delete action when `ProfileDto.canDelete` is `false`.
Each disabled action SHALL carry a tooltip stating the reason:

| Action | Condition | Tooltip |
|---|---|---|
| Modifier | `!canManage` | "Profil partagé en lecture seule" |
| Supprimer | `isMain` | "Le profil principal ne peut pas être supprimé" |
| Supprimer | `shared` | "Profil partagé : seul son propriétaire peut le supprimer" |

These gates are an **affordance**, not a security boundary: the backend
remains the source of truth and answers `403 not_profile_owner` on the
same cases. The UI only spares the user a round-trip that is guaranteed
to fail, and a refusal they could not have anticipated.

`ProfileDto` SHALL carry `shared`, `canManage` and `canDelete`, projected
from the corresponding `Profile` fields. `canDelete` is computed on the
Domain entity rather than recomputed in the UI, so the rule lives in one
place.

#### Scenario: A shared read-only profile

- **GIVEN** a profile with `shared == true` and `canManage == false`
- **WHEN** the management list renders its tile
- **THEN** a "Partagé" badge is displayed
- **AND** the edit action is disabled
- **AND** the delete action is disabled

#### Scenario: A shared manageable profile

- **GIVEN** a profile with `shared == true` and `canManage == true`
- **WHEN** the management list renders its tile
- **THEN** a "Partagé" badge is displayed
- **AND** the edit action is enabled
- **AND** the delete action is disabled, with the "seul son propriétaire" tooltip

#### Scenario: An owned profile is unaffected

- **GIVEN** a profile with `shared == false`, `canManage == true` and `isMain == false`
- **WHEN** the management list renders its tile
- **THEN** no "Partagé" badge is displayed
- **AND** both the edit and delete actions are enabled

## MODIFIED Requirements

### Requirement: Delete a profile

The system SHALL expose an application-layer usecase `DeleteProfileUseCase` that accepts a profile id and removes it from the session's profile list.

The usecase SHALL only be callable when the session is in `ManagingProfiles` state. Otherwise it SHALL return a failure result flagged `invalidState`.

If the target profile id does not exist, the usecase SHALL return a failure result flagged `unknownProfile`.

If the target profile has `isMain == true`, the underlying `ProfileManagementRepository.delete(...)` SHALL throw `CannotDeleteMainProfileException`. The usecase SHALL catch this exception and return a failure result flagged `cannotDeleteMain`. The UI SHALL visually disable the delete action on the main profile as an additional safeguard.

If the target profile has `shared == true`, the HTTP repository SHALL receive `403 not_profile_owner` from the backend — deleting cascades on the owner household's watch progress, favorites and seen marks, so it stays owner-only whatever `canManage` says. The UI SHALL visually disable the delete action on shared profiles (cf. requirement "Shared profiles are visually distinguished and their actions gated"), so this path is not reachable from the management list; it remains the backend's guarantee rather than the app's.

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

#### Scenario: The delete affordance is absent on a shared profile

- **GIVEN** a session in state `ManagingProfiles(session)` containing a profile with `shared == true`
- **WHEN** the management list renders
- **THEN** the delete action on that profile is disabled
- **AND** `DeleteProfileUseCase.execute(...)` is never reached for it
