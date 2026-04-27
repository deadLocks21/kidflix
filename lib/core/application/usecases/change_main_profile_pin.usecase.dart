import 'package:kidflix/core/domain/exceptions/unknown_profile.exception.dart';
import 'package:kidflix/core/domain/model/profile.dart';
import 'package:kidflix/core/domain/model/session.dart';
import 'package:kidflix/core/domain/services/profile_management.repository.dart';

/// Result of [ChangeMainProfilePinUseCase.execute].
sealed class ChangeMainProfilePinResult {
  const ChangeMainProfilePinResult();
}

class ChangeMainProfilePinSuccess extends ChangeMainProfilePinResult {
  final Profile profile;

  const ChangeMainProfilePinSuccess(this.profile);
}

class ChangeMainProfilePinMismatch extends ChangeMainProfilePinResult {
  const ChangeMainProfilePinMismatch();
}

class ChangeMainProfilePinInvalidPin extends ChangeMainProfilePinResult {
  const ChangeMainProfilePinInvalidPin();
}

class ChangeMainProfilePinNoMainProfile extends ChangeMainProfilePinResult {
  const ChangeMainProfilePinNoMainProfile();
}

class ChangeMainProfilePinUnknownProfile extends ChangeMainProfilePinResult {
  const ChangeMainProfilePinUnknownProfile();
}

class ChangeMainProfilePinInvalidState extends ChangeMainProfilePinResult {
  const ChangeMainProfilePinInvalidState();
}

/// Replaces the PIN of the account's main profile. Enforces double-entry
/// confirmation: if [newPin] and [confirmPin] differ the usecase fails
/// fast without calling the repository (no bcrypt hashing is performed).
class ChangeMainProfilePinUseCase {
  static final RegExp _pinPattern = RegExp(r'^[0-9]{4}$');

  final ProfileManagementRepository _repo;

  const ChangeMainProfilePinUseCase(this._repo);

  Future<ChangeMainProfilePinResult> execute({
    required Session session,
    required String newPin,
    required String confirmPin,
  }) async {
    if (newPin != confirmPin) {
      return const ChangeMainProfilePinMismatch();
    }
    if (!_pinPattern.hasMatch(newPin)) {
      return const ChangeMainProfilePinInvalidPin();
    }
    Profile? main;
    for (final p in session.profiles) {
      if (p.isMain) {
        main = p;
        break;
      }
    }
    if (main == null) return const ChangeMainProfilePinNoMainProfile();
    try {
      final updated = await _repo.setPin(id: main.id, rawPin: newPin);
      return ChangeMainProfilePinSuccess(updated);
    } on UnknownProfileException {
      return const ChangeMainProfilePinUnknownProfile();
    }
  }
}
