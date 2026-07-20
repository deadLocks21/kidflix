import 'dart:async';

import 'package:dio/dio.dart';
import 'package:kidflix/infrastructure/http/auth.interceptor.dart';
import 'package:kidflix/infrastructure/providers/api_base_url.provider.dart';
import 'package:kidflix/infrastructure/providers/current_profile_id.provider.dart';
import 'package:kidflix/infrastructure/providers/current_session.provider.dart';
import 'package:kidflix/infrastructure/providers/session.controller_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'dio.provider.g.dart';

/// Centralized Dio HTTP client shared by every `dio.<thing>.repository.dart`.
///
/// The `baseUrl` is sourced from [apiBaseUrlProvider], which lets the user
/// pick a backend at runtime via the ⚙ dialog on the phone-entry page.
/// Persistence is handled by `SharedPreferences`; the compile-time constant
/// `String.fromEnvironment('API_BASE_URL')` is used as a fallback when
/// nothing has ever been stored. An empty URL keeps the app in in-memory
/// mode (the repository providers select their `InMemory*` implementations).
///
/// Example launches that bake an initial URL into the build:
///
/// ```sh
/// flutter run --dart-define=API_BASE_URL=http://localhost:8080  # iOS Simulator
/// flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080   # Android emulator
/// ```
///
/// Changing the URL at runtime invalidates this provider via the
/// `ref.watch` below, so a fresh `Dio` instance is created with the new
/// `baseUrl` (losing the connection pool — acceptable for an infrequent
/// configuration change).
///
/// An [AuthInterceptor] is wired in to add `Authorization: Bearer <jwt>`,
/// `X-Device-Id: <uuid>` and `X-Profile-Id: <profile_id>` headers on every
/// protected request, sourcing the current session from
/// [currentSessionProvider] and the active profile id from
/// [currentProfileIdProvider]. The interceptor itself skips the public
/// `/auth/*` endpoints (no header at all) and exempts `GET /profiles` from
/// `X-Profile-Id` injection (bootstrap route).
///
/// The same interceptor watches responses for `401 invalid_token` and hands
/// off to [SessionController.handleExpiredToken], which re-issues an OTP and
/// drops the user on the verification screen. `unawaited` keeps the error
/// path non-blocking: the original `DioException` still surfaces to the
/// calling repository, the recovery runs beside it.
///
/// All three callbacks are read via `ref.read` (not `ref.watch`) so
/// login/logout transitions AND profile-selection transitions do NOT rebuild
/// this `Dio`. The interceptor reads the latest values lazily at every
/// request. Reading `sessionControllerProvider` lazily also breaks what would
/// otherwise be a build-time cycle (`dio → sessionController → authService →
/// authRepository → dio`).
@Riverpod(keepAlive: true)
Dio dio(Ref ref) {
  final baseUrl = ref.watch(apiBaseUrlProvider);
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
      onUnauthorized: () => unawaited(
        ref.read(sessionControllerProvider.notifier).handleExpiredToken(),
      ),
    ),
  );
  return dio;
}
