import 'package:dio/dio.dart';
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
/// **No auth interceptors are registered here.** The `/auth/*` endpoints are
/// public per `API.md`, so an `Authorization: Bearer <jwt>` /
/// `X-Device-Id: <uuid>` interceptor would be dead code at this stage. They
/// must be added when the first protected capability (catalog,
/// profile-management, …) is ported to HTTP.
@Riverpod(keepAlive: true)
Dio dio(Ref ref) {
  const baseUrl = String.fromEnvironment('API_BASE_URL');
  return Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
      contentType: 'application/json',
      responseType: ResponseType.json,
    ),
  );
}
