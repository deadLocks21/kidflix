import 'package:kidflix/core/domain/exceptions/invalid_profile_name.exception.dart';
import 'package:kidflix/core/domain/model/profile.dart';
import 'package:kidflix/core/domain/model/session.dart';
import 'package:kidflix/core/domain/services/profile_management.repository.dart';

/// Result of [UpdateProfileMetadataUseCase.execute].
sealed class UpdateProfileMetadataResult {
  const UpdateProfileMetadataResult();
}

class UpdateProfileMetadataSuccess extends UpdateProfileMetadataResult {
  final Profile profile;

  const UpdateProfileMetadataSuccess(this.profile);
}

class UpdateProfileMetadataInvalidName extends UpdateProfileMetadataResult {
  final InvalidProfileNameReason reason;

  const UpdateProfileMetadataInvalidName(this.reason);
}

class UpdateProfileMetadataUnknownProfile extends UpdateProfileMetadataResult {
  const UpdateProfileMetadataUnknownProfile();
}

class UpdateProfileMetadataInvalidState extends UpdateProfileMetadataResult {
  const UpdateProfileMetadataInvalidState();
}

/// Updates the display name and age category of a profile. Preserves
/// `isMain`, `pinHash` and `avatarUrl`.
class UpdateProfileMetadataUseCase {
  static const int _maxNameLength = 30;

  final ProfileManagementRepository _repo;

  const UpdateProfileMetadataUseCase(this._repo);

  Future<UpdateProfileMetadataResult> execute({
    required Session session,
    required String profileId,
    required String rawName,
    required AgeCategory ageCategory,
  }) async {
    final exists = session.profiles.any((p) => p.id == profileId);
    if (!exists) return const UpdateProfileMetadataUnknownProfile();

    final trimmed = rawName.trim();
    if (trimmed.isEmpty) {
      return const UpdateProfileMetadataInvalidName(
        InvalidProfileNameReason.empty,
      );
    }
    if (trimmed.length > _maxNameLength) {
      return const UpdateProfileMetadataInvalidName(
        InvalidProfileNameReason.tooLong,
      );
    }

    final updated = await _repo.updateMetadata(
      id: profileId,
      name: trimmed,
      ageCategory: ageCategory,
    );
    return UpdateProfileMetadataSuccess(updated);
  }
}
