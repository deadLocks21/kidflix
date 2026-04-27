import 'package:dio/dio.dart';
import 'package:kidflix/infrastructure/http/auth.interceptor.dart';
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
/// An [AuthInterceptor] is wired in to add `Authorization: Bearer <jwt>` and
/// `X-Device-Id: <uuid>` headers on every protected request, sourcing the
/// current session from [currentSessionProvider]. The interceptor itself
/// skips the public `/auth/*` endpoints — they expect no auth headers per
/// `API.md` § Conventions.
///
/// The session is read via `ref.read` (not `ref.watch`) inside the
/// interceptor's callback so login/logout transitions do NOT rebuild this
/// `Dio` (which would lose the connection pool). The interceptor reads the
/// latest session lazily at every request.
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
    AuthInterceptor(() => ref.read(currentSessionProvider)),
  );
  return dio;
}
