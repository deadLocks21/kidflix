import 'package:kidflix/core/domain/model/profile.dart';
import 'package:kidflix/core/domain/services/auth.repository.dart';

/// Re-fetches the up-to-date list of profiles for the current user via
/// [AuthRepository.fetchProfiles] so the caller can refresh
/// `session.profiles` after external mutations (new profile created on
/// another device, PIN updated, profile deleted).
///
/// This usecase intentionally does NOT mutate the session itself —
/// state ownership belongs to the `SessionController`. Callers consume
/// the returned list and pass it to `SessionController.replaceProfiles`,
/// which both persists the updated session and emits the same
/// `SessionState` variant with the new profile list (or throws
/// `StateError` when called from a state that carries no session).
///
/// Deux déclencheurs sont câblés, tous deux best-effort (un échec réseau
/// laisse la session restaurée intacte) :
///
/// - `bootstrap()` après `restoreSession()`, au démarrage à froid ;
/// - l'entrée sur l'écran de sélection de profils, qui couvre le cas d'un
///   profil partagé depuis un autre compte pendant que l'app tourne — il
///   n'apparaîtrait sinon qu'au prochain redémarrage complet.
class RefreshProfilesUseCase {
  final AuthRepository _repo;

  const RefreshProfilesUseCase(this._repo);

  Future<List<Profile>> execute() => _repo.fetchProfiles();
}
