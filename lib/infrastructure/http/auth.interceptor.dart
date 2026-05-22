import 'package:dio/dio.dart';
import 'package:kidflix/core/domain/model/session.dart';

/// Dio interceptor that injects `Authorization: Bearer <jwt>`,
/// `X-Device-Id: <uuid>` and `X-Profile-Id: <profile_id>` headers on every
/// protected outbound request.
///
/// Three exemption rules:
///
/// 1. **Public auth routes.** Requests whose path starts with `/auth/` are
///    forwarded as-is without any header. They are public per `API.md`
///    § Conventions and adding auth headers would mislead the backend.
/// 2. **Bootstrap profile route.** `GET /profiles` (path `'/profiles'` AND
///    method `'GET'`, exact match) receives `Authorization` and
///    `X-Device-Id` but **NOT** `X-Profile-Id` — it is the route used to
///    resync the profile list before any profile is selected. Other
///    `/profiles*` paths (`POST /profiles`, `PATCH /profiles/:id`,
///    `DELETE /profiles/:id`, `PUT /profiles/:id/pin`,
///    `DELETE /profiles/:id/pin`) DO receive `X-Profile-Id` normally.
/// 3. **Null callbacks.** When `_currentSession()` returns `null`, no
///    header is injected — the backend rejects with `401 invalid_token`.
///    When `_currentProfileId()` returns `null` on a non-exempt protected
///    route, only `X-Profile-Id` is omitted (the backend will respond
///    `400 missing_profile_id`, surfaced as a generic `DioException`).
///
/// Both callbacks are read lazily at every request, so a single interceptor
/// instance handles login/logout cycles AND profile-selection transitions
/// without recreating Dio. The interceptor itself has no dependency on
/// Riverpod or any framework — its callsite (`dioProvider`) is in charge
/// of bridging to the session source (typically `currentSessionProvider`)
/// and the profile-id source (typically `currentProfileIdProvider`).
class AuthInterceptor extends Interceptor {
  AuthInterceptor({
    required Session? Function() session,
    required String? Function() profileId,
  }) : _currentSession = session,
       _currentProfileId = profileId;

  final Session? Function() _currentSession;
  final String? Function() _currentProfileId;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (options.path.startsWith('/auth/')) {
      return handler.next(options);
    }
    final session = _currentSession();
    if (session != null) {
      options.headers['Authorization'] = 'Bearer ${session.jwt}';
      options.headers['X-Device-Id'] = session.device.id;
    }
    final isProfilesBootstrap =
        options.path == '/profiles' && options.method.toUpperCase() == 'GET';
    if (!isProfilesBootstrap) {
      // A caller MAY pre-set `X-Profile-Id` via per-call `Options.headers`
      // to query the backend on behalf of a profile other than the
      // currently-active one (e.g. the downloads manager unioning
      // catalog calls across every family profile to find titles for
      // items downloaded by any kid). The interceptor preserves such an
      // explicit override and only injects from `_currentProfileId()`
      // when no override is present.
      if (!options.headers.containsKey('X-Profile-Id')) {
        final profileId = _currentProfileId();
        if (profileId != null) {
          options.headers['X-Profile-Id'] = profileId;
        }
      }
    }
    handler.next(options);
  }
}
