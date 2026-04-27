import 'package:kidflix/core/domain/exceptions/unknown_profile.exception.dart';
import 'package:kidflix/core/domain/model/profile.dart';
import 'package:kidflix/core/domain/model/session.dart';
import 'package:kidflix/core/domain/services/profile_management.repository.dart';

/// Result of [ChangeProfilePinUseCase.execute].
sealed class ChangeProfilePinResult {
  const ChangeProfilePinResult();
}

class ChangeProfilePinSuccess extends ChangeProfilePinResult {
  final Profile profile;

  const ChangeProfilePinSuccess(this.profile);
}

class ChangeProfilePinInvalidPin extends ChangeProfilePinResult {
  const ChangeProfilePinInvalidPin();
}

class ChangeProfilePinUnknownProfile extends ChangeProfilePinResult {
  const ChangeProfilePinUnknownProfile();
}

class ChangeProfilePinInvalidState extends ChangeProfilePinResult {
  const ChangeProfilePinInvalidState();
}

/// Sets or replaces the PIN of a profile. Not responsible for the
/// double-entry confirmation that applies to the main profile — callers
/// wanting that safety net MUST use `ChangeMainProfilePinUseCase`.
class ChangeProfilePinUseCase {
  static final RegExp _pinPattern = RegExp(r'^[0-9]{4}$');

  final ProfileManagementRepository _repo;

  const ChangeProfilePinUseCase(this._repo);

  Future<ChangeProfilePinResult> execute({
    required Session session,
    required String profileId,
    required String rawPin,
  }) async {
    final exists = session.profiles.any((p) => p.id == profileId);
    if (!exists) return const ChangeProfilePinUnknownProfile();
    if (!_pinPattern.hasMatch(rawPin)) {
      return const ChangeProfilePinInvalidPin();
    }
    try {
      final updated = await _repo.setPin(id: profileId, rawPin: rawPin);
      return ChangeProfilePinSuccess(updated);
    } on UnknownProfileException {
      return const ChangeProfilePinUnknownProfile();
    }
  }
}
