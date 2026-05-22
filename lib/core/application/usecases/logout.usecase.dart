import 'package:kidflix/core/application/services/logger_application.service.dart';
import 'package:kidflix/core/domain/services/session.repository.dart';

/// Clears the persisted session while preserving the device id.
class LogoutUseCase {
  final SessionRepository _sessions;
  final LoggerApplicationService _logger;

  const LogoutUseCase(this._sessions, this._logger);

  Future<void> execute() async {
    await _logger.info('auth.logout');
    await _sessions.clearSessionPreserveDevice();
  }
}
