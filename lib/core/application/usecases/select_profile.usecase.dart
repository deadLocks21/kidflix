import 'package:kidflix/core/domain/model/profile.dart';
import 'package:kidflix/core/domain/model/session.dart';

/// Result of [SelectProfileUseCase.execute].
sealed class SelectProfileResult {
  const SelectProfileResult();
}

/// Profil sans PIN : l'utilisateur peut entrer directement sur la home.
class SelectProfileReady extends SelectProfileResult {
  final Profile profile;

  const SelectProfileReady(this.profile);
}

/// Profil avec PIN : le PIN doit être saisi avant d'entrer.
class SelectProfilePinRequired extends SelectProfileResult {
  final Profile profile;

  const SelectProfilePinRequired(this.profile);
}

class SelectProfileUnknown extends SelectProfileResult {
  const SelectProfileUnknown();
}

/// Resolves a profile by id from the active session and decides whether
/// it requires PIN verification.
class SelectProfileUseCase {
  const SelectProfileUseCase();

  SelectProfileResult execute({
    required Session session,
    required String profileId,
  }) {
    Profile? found;
    for (final p in session.profiles) {
      if (p.id == profileId) {
        found = p;
        break;
      }
    }
    if (found == null) return const SelectProfileUnknown();
    return found.hasPin
        ? SelectProfilePinRequired(found)
        : SelectProfileReady(found);
  }
}
