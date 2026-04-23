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

  const RestoreSessionUseCase(this._sessions);

  Future<RestoreSessionResult> execute() async {
    try {
      final session = await _sessions.read();
      if (session == null) {
        return const RestoreSessionNone();
      }
      return RestoreSessionFound(session);
    } catch (_) {
      await _sessions.clearSessionPreserveDevice();
      return const RestoreSessionNone();
    }
  }
}
