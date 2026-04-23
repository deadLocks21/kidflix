import 'package:kidflix/core/domain/model/profile.dart';
import 'package:kidflix/core/domain/model/session.dart';

/// Result of [EnterManagementModeUseCase.execute].
sealed class EnterManagementModeResult {
  const EnterManagementModeResult();
}

class EnterManagementModeSuccess extends EnterManagementModeResult {
  final Profile mainProfile;

  const EnterManagementModeSuccess(this.mainProfile);
}

class EnterManagementModeNoMainProfile extends EnterManagementModeResult {
  const EnterManagementModeNoMainProfile();
}

class EnterManagementModeInvalidState extends EnterManagementModeResult {
  const EnterManagementModeInvalidState();
}

/// Looks up the account's main profile and indicates whether the caller can
/// transition into management mode. The caller (session controller) is
/// responsible for the actual state transition.
class EnterManagementModeUseCase {
  const EnterManagementModeUseCase();

  EnterManagementModeResult execute({required Session session}) {
    Profile? main;
    for (final p in session.profiles) {
      if (p.isMain) {
        main = p;
        break;
      }
    }
    if (main == null) return const EnterManagementModeNoMainProfile();
    return EnterManagementModeSuccess(main);
  }
}
