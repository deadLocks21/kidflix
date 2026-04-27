## REMOVED Requirements

### Requirement: Public `ageCategoryToWire` helper

**Reason**: The helper is no longer specific to profile management. With the introduction of `RemoteMovieDto` (in the `catalog` capability), a second wire DTO consumes the same enum mapping. Keeping the helper in `remote_profile.dto.dart` would force `remote_movie.dto.dart` to import a profile-named file for a generic enum-serialization concern (a misleading import).

The helper has been relocated to a dedicated shared file `lib/core/application/dtos/age_category_wire.dart` and is now described by the `catalog` capability requirement "Shared wire helpers for AgeCategory". The location move includes a complementary promotion: the previously-private `_ageCategoryFromWire` is exposed as the public `ageCategoryFromWire` alongside `ageCategoryToWire`, so `RemoteMovieDto.fromJson` can consume it.

No runtime behavior changes: the mapping table and the `FormatException` semantics on unknown values are preserved verbatim. `RemoteProfileDto.fromJson` and `RemoteProfileDto.toJson` continue to use the helpers internally — they just import them from the new path.

**Migration**:

- Code that imports `ageCategoryToWire` from `package:kidflix/core/application/dtos/remote_profile.dto.dart` SHALL update its import to `package:kidflix/core/application/dtos/age_category_wire.dart`. Affected call sites in this change: `dio.profile_management.repository.dart`.
- Code that previously could not access `_ageCategoryFromWire` (private) MAY now consume the public `ageCategoryFromWire` from the new path. New consumer: `RemoteMovieDto.fromJson`.
- The two functions remain top-level public, with identical signatures and behavior. No call site needs to adapt beyond the import path.
- The mapping table (`bebe`, `enfant`, `ado`, `jeune_adulte`, `adulte`) is unchanged. Tests asserting wire strings continue to pass.
