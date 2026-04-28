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
/// No automatic trigger (foreground, pull-to-refresh, periodic timer) is
/// wired in this change — the usecase ships ready to be consumed by a
/// future change that picks the right UX trigger.
class RefreshProfilesUseCase {
  final AuthRepository _repo;

  const RefreshProfilesUseCase(this._repo);

  Future<List<Profile>> execute() => _repo.fetchProfiles();
}
