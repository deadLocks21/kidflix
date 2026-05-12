import 'package:kidflix/core/domain/exceptions/unknown_profile.exception.dart';
import 'package:kidflix/core/domain/model/profile.dart';
import 'package:kidflix/core/domain/model/session.dart';
import 'package:kidflix/core/domain/services/profile_management.repository.dart';

/// Result of [UpdateProfileIncludedLowerAgesUseCase.execute].
sealed class UpdateProfileIncludedLowerAgesResult {
  const UpdateProfileIncludedLowerAgesResult();
}

class UpdateProfileIncludedLowerAgesSuccess
    extends UpdateProfileIncludedLowerAgesResult {
  final Profile profile;

  const UpdateProfileIncludedLowerAgesSuccess(this.profile);
}

class UpdateProfileIncludedLowerAgesUnknownProfile
    extends UpdateProfileIncludedLowerAgesResult {
  const UpdateProfileIncludedLowerAgesUnknownProfile();
}

class UpdateProfileIncludedLowerAgesInvalidState
    extends UpdateProfileIncludedLowerAgesResult {
  const UpdateProfileIncludedLowerAgesInvalidState();
}

/// At least one entry in the input was not strictly lower than the
/// profile's own [AgeCategory] (or was a duplicate).
class UpdateProfileIncludedLowerAgesInvalidCategories
    extends UpdateProfileIncludedLowerAgesResult {
  const UpdateProfileIncludedLowerAgesInvalidCategories();
}

/// Replaces the opt-in list of *strictly lower* age categories a profile
/// wants to see on its homepage. The repository performs the write,
/// validation is enforced here so the wire payload is always coherent.
class UpdateProfileIncludedLowerAgesUseCase {
  final ProfileManagementRepository _repo;

  const UpdateProfileIncludedLowerAgesUseCase(this._repo);

  Future<UpdateProfileIncludedLowerAgesResult> execute({
    required Session session,
    required String profileId,
    required List<AgeCategory> categories,
  }) async {
    final target = session.profiles
        .where((p) => p.id == profileId)
        .firstOrNull;
    if (target == null) {
      return const UpdateProfileIncludedLowerAgesUnknownProfile();
    }

    final asSet = categories.toSet();
    if (asSet.length != categories.length) {
      return const UpdateProfileIncludedLowerAgesInvalidCategories();
    }
    final outOfRange = asSet.any((c) => c.index >= target.ageCategory.index);
    if (outOfRange) {
      return const UpdateProfileIncludedLowerAgesInvalidCategories();
    }

    final ordered = AgeCategory.values
        .where(asSet.contains)
        .toList(growable: false);

    try {
      final updated = await _repo.updateIncludedLowerAgeCategories(
        id: profileId,
        categories: ordered,
      );
      return UpdateProfileIncludedLowerAgesSuccess(updated);
    } on UnknownProfileException {
      return const UpdateProfileIncludedLowerAgesUnknownProfile();
    }
  }
}
