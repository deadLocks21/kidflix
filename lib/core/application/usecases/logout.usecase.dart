import 'package:kidflix/core/domain/services/session.repository.dart';

/// Clears the persisted session while preserving the device id.
class LogoutUseCase {
  final SessionRepository _sessions;

  const LogoutUseCase(this._sessions);

  Future<void> execute() => _sessions.clearSessionPreserveDevice();
}
