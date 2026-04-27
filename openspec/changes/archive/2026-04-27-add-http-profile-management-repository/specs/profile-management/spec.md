## ADDED Requirements

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

## MODIFIED Requirements

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
