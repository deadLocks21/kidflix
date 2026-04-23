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
  /// it is hashed with bcrypt before persistence. The returned [Profile]
  /// carries the newly-generated stable id.
  Future<Profile> create({
    required String name,
    required AgeCategory ageCategory,
    String? rawPin,
  });

  /// Updates the display name and age category of the profile with [id].
  /// Preserves `isMain`, `pinHash` and `avatarUrl`.
  Future<Profile> updateMetadata({
    required String id,
    required String name,
    required AgeCategory ageCategory,
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
