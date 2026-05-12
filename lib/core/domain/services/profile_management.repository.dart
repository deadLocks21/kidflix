import 'package:kidflix/core/domain/model/avatar_update.dart';
import 'package:kidflix/core/domain/model/profile.dart';

/// Contract for creating, updating and deleting profiles attached to an
/// authenticated account.
///
/// Implementations live in `lib/infrastructure/profile_management/`.
///
/// All mutations preserve the `isMain` flag of the target profile. No path
/// on this interface creates a profile with `isMain == true` — the main
/// profile is created server-side alongside the user account.
abstract interface class ProfileManagementRepository {
  /// Creates a new profile with `isMain == false`. If [rawPin] is provided,
  /// it is hashed with bcrypt before persistence. If [avatarId] is provided,
  /// it must be an id from the server-side avatar catalogue (validated
  /// against `AvatarsRepository.list()` upstream). The returned [Profile]
  /// carries the newly-generated stable id.
  Future<Profile> create({
    required String name,
    required AgeCategory ageCategory,
    String? rawPin,
    String? avatarId,
  });

  /// Updates the display name and age category of the profile with [id].
  /// [avatar] controls the `avatarId` field per the tri-state contract.
  /// Preserves `isMain` and `pinHash`.
  Future<Profile> updateMetadata({
    required String id,
    required String name,
    required AgeCategory ageCategory,
    AvatarUpdate avatar = const AvatarUnchanged(),
  });

  /// Replaces the profile's [Profile.includedLowerAgeCategories] with
  /// [categories]. Caller is responsible for ensuring every entry is
  /// strictly lower than the profile's [Profile.ageCategory] — the
  /// repository assumes pre-validated input.
  ///
  /// Preserves all other fields. Returns the updated [Profile].
  Future<Profile> updateIncludedLowerAgeCategories({
    required String id,
    required List<AgeCategory> categories,
  });

  /// Sets or replaces the PIN of the profile with [id]. Hashes [rawPin]
  /// with bcrypt. Preserves all other fields including `isMain`.
  Future<Profile> setPin({required String id, required String rawPin});

  /// Removes the PIN of the profile with [id] (sets `pinHash` to `null`).
  ///
  /// Throws `CannotClearMainProfilePinException` if the target profile has
  /// `isMain == true`.
  Future<Profile> clearPin({required String id});

  /// Deletes the profile with [id].
  ///
  /// Throws `CannotDeleteMainProfileException` if the target profile has
  /// `isMain == true`.
  Future<void> delete({required String id});
}
