import 'package:dio/dio.dart';
import 'package:kidflix/core/domain/model/session.dart';

/// Dio interceptor that injects `Authorization: Bearer <jwt>` and
/// `X-Device-Id: <uuid>` headers on every protected outbound request.
///
/// Public `/auth/*` endpoints (per `API.md` § Conventions) are skipped — they
/// expect no auth headers, and adding them would mislead the backend.
///
/// The current session is read lazily at every request via the
/// constructor-injected callback, so a single interceptor instance handles
/// login/logout cycles without recreating Dio. The interceptor itself has no
/// dependency on Riverpod or any framework — its callsite (`dioProvider`) is
/// in charge of bridging to the session source (typically
/// `currentSessionProvider`).
///
/// When the callback returns `null` the interceptor lets the request through
/// **without** auth headers — the backend is the source of truth for auth
/// status and rejects with `401 invalid_token` if needed. This matches the
/// project's stance: client-side short-circuiting would mask real bugs.
class AuthInterceptor extends Interceptor {
  AuthInterceptor(this._currentSession);

  final Session? Function() _currentSession;

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) {
    if (options.path.startsWith('/auth/')) {
      return handler.next(options);
    }
    final session = _currentSession();
    if (session != null) {
      options.headers['Authorization'] = 'Bearer ${session.jwt}';
      options.headers['X-Device-Id'] = session.device.id;
    }
    handler.next(options);
  }
}
