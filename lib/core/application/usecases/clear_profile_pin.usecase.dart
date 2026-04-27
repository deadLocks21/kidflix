import 'package:kidflix/core/domain/exceptions/cannot_clear_main_profile_pin.exception.dart';
import 'package:kidflix/core/domain/exceptions/unknown_profile.exception.dart';
import 'package:kidflix/core/domain/model/profile.dart';
import 'package:kidflix/core/domain/model/session.dart';
import 'package:kidflix/core/domain/services/profile_management.repository.dart';

/// Result of [ClearProfilePinUseCase.execute].
sealed class ClearProfilePinResult {
  const ClearProfilePinResult();
}

class ClearProfilePinSuccess extends ClearProfilePinResult {
  final Profile profile;

  const ClearProfilePinSuccess(this.profile);
}

class ClearProfilePinUnknownProfile extends ClearProfilePinResult {
  const ClearProfilePinUnknownProfile();
}

class ClearProfilePinCannotClearMain extends ClearProfilePinResult {
  const ClearProfilePinCannotClearMain();
}

class ClearProfilePinInvalidState extends ClearProfilePinResult {
  const ClearProfilePinInvalidState();
}

/// Removes the PIN from a standard profile. Rejects the operation on the
/// main profile via a Domain exception caught and mapped to a UI-ready
/// failure flag.
class ClearProfilePinUseCase {
  final ProfileManagementRepository _repo;

  const ClearProfilePinUseCase(this._repo);

  Future<ClearProfilePinResult> execute({
    required Session session,
    required String profileId,
  }) async {
    final exists = session.profiles.any((p) => p.id == profileId);
    if (!exists) return const ClearProfilePinUnknownProfile();
    try {
      final updated = await _repo.clearPin(id: profileId);
      return ClearProfilePinSuccess(updated);
    } on CannotClearMainProfilePinException {
      return const ClearProfilePinCannotClearMain();
    } on UnknownProfileException {
      return const ClearProfilePinUnknownProfile();
    }
  }
}
