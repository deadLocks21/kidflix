import 'package:kidflix/core/application/services/logger_application.service.dart';
import 'package:kidflix/core/domain/model/session.dart';
import 'package:kidflix/core/domain/services/session.repository.dart';

/// Result of [RestoreSessionUseCase.execute].
sealed class RestoreSessionResult {
  const RestoreSessionResult();
}

class RestoreSessionFound extends RestoreSessionResult {
  final Session session;

  const RestoreSessionFound(this.session);
}

class RestoreSessionNone extends RestoreSessionResult {
  const RestoreSessionNone();
}

/// Attempts to rebuild a [Session] from persisted storage at startup.
class RestoreSessionUseCase {
  final SessionRepository _sessions;
  final LoggerApplicationService _logger;

  const RestoreSessionUseCase(this._sessions, this._logger);

  Future<RestoreSessionResult> execute() async {
    try {
      final session = await _sessions.read();
      if (session == null) {
        // Absence de session au premier lancement : cas normal, pas de log.
        return const RestoreSessionNone();
      }
      await _logger.info('auth.session.restored');
      return RestoreSessionFound(session);
    } catch (e, st) {
      await _logger.warn('auth.session.restore_failed', error: e, stack: st);
      await _sessions.clearSessionPreserveDevice();
      return const RestoreSessionNone();
    }
  }
}
