import 'package:dio/dio.dart';
import 'package:kidflix/infrastructure/http/auth.interceptor.dart';
import 'package:kidflix/infrastructure/providers/current_profile_id.provider.dart';
import 'package:kidflix/infrastructure/providers/current_session.provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'dio.provider.g.dart';

/// Centralized Dio HTTP client shared by every `dio.<thing>.repository.dart`.
///
/// The `baseUrl` is resolved from the compile-time constant
/// `String.fromEnvironment('API_BASE_URL')` so the build defaults to an empty
/// URL (in-memory mode) and switches to HTTP when launched with
/// `--dart-define=API_BASE_URL=...`.
///
/// Example launches against a local backend:
///
/// ```sh
/// flutter run --dart-define=API_BASE_URL=http://localhost:8080  # iOS Simulator
/// flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080   # Android emulator
/// ```
///
/// An [AuthInterceptor] is wired in to add `Authorization: Bearer <jwt>`,
/// `X-Device-Id: <uuid>` and `X-Profile-Id: <profile_id>` headers on every
/// protected request, sourcing the current session from
/// [currentSessionProvider] and the active profile id from
/// [currentProfileIdProvider]. The interceptor itself skips the public
/// `/auth/*` endpoints (no header at all) and exempts `GET /profiles` from
/// `X-Profile-Id` injection (bootstrap route).
///
/// Both callbacks are read via `ref.read` (not `ref.watch`) so login/logout
/// transitions AND profile-selection transitions do NOT rebuild this `Dio`
/// (which would lose the connection pool). The interceptor reads the
/// latest values lazily at every request.
@Riverpod(keepAlive: true)
Dio dio(Ref ref) {
  const baseUrl = String.fromEnvironment('API_BASE_URL');
  final dio = Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
      contentType: 'application/json',
      responseType: ResponseType.json,
    ),
  );
  dio.interceptors.add(
    AuthInterceptor(
      session: () => ref.read(currentSessionProvider),
      profileId: () => ref.read(currentProfileIdProvider),
    ),
  );
  return dio;
}
