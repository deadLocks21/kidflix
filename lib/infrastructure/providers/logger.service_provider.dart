import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:kidflix/core/application/services/logger_application.service.dart';
import 'package:kidflix/core/domain/services/logger.service.dart';
import 'package:kidflix/infrastructure/logger/composite.logger.service.dart';
import 'package:kidflix/infrastructure/logger/console.logger.service.dart';
import 'package:kidflix/infrastructure/logger/signoz.logger.service.dart';
import 'package:kidflix/infrastructure/providers/current_profile_id.provider.dart';
import 'package:kidflix/infrastructure/providers/current_session.provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'logger.service_provider.g.dart';

/// Build-time Signoz OTLP HTTP endpoint, e.g.
/// `https://ingest.eu.signoz.cloud:443/v1/logs`. Empty → Signoz disabled.
///
/// Pass via:
/// `flutter run --dart-define=SIGNOZ_INGEST_URL=https://…/v1/logs`
const String _kSignozEndpoint = String.fromEnvironment('SIGNOZ_INGEST_URL');

/// Build-time Signoz Cloud ingestion key. Sent as `signoz-access-token`.
/// Leave empty for self-hosted deployments without auth.
const String _kSignozKey = String.fromEnvironment('SIGNOZ_INGESTION_KEY');

/// Optional override for the `deployment.environment` resource attribute.
/// Defaults to `production` in release builds, `development` otherwise.
const String _kEnvOverride = String.fromEnvironment('SIGNOZ_ENV');

/// App version surfaced as the `service.version` resource attribute.
/// The codemagic build can inject the real value via
/// `--dart-define=APP_VERSION=$VERSION+$BUILD_NUMBER`. Defaults to a
/// sentinel so unconfigured local builds are obvious in Signoz.
const String _kAppVersion = String.fromEnvironment(
  'APP_VERSION',
  defaultValue: 'dev',
);

/// Single app-wide [LoggerService].
///
/// Selection logic:
///
/// | Mode    | SIGNOZ_INGEST_URL set | Implementation                          |
/// |---------|-----------------------|-----------------------------------------|
/// | release | no                    | [ConsoleLoggerService] (fail-safe)      |
/// | release | yes                   | [SignozLoggerService] alone             |
/// | debug   | no                    | [ConsoleLoggerService] alone            |
/// | debug   | yes                   | [CompositeLoggerService]: console+signoz|
///
/// The debug+signoz branch is what lets the developer see in their own
/// console exactly what is being shipped — see `calibration` discussion
/// in `LoggerService`'s doc.
///
/// `keepAlive` because the underlying Signoz adapter holds a periodic
/// timer + dio client that would be wasteful to spin up on demand.
@Riverpod(keepAlive: true)
LoggerService loggerService(Ref ref) {
  final hasSignoz = _kSignozEndpoint.isNotEmpty;

  final console = ConsoleLoggerService(
    prefix: hasSignoz && !kReleaseMode ? '[→signoz]' : null,
  );

  if (!hasSignoz) {
    return console;
  }

  final signoz = SignozLoggerService(
    endpoint: _kSignozEndpoint,
    ingestionKey: _kSignozKey.isEmpty ? null : _kSignozKey,
    resourceAttributes: _resourceAttributes(),
  );
  ref.onDispose(signoz.dispose);

  if (kReleaseMode) {
    return signoz;
  }
  // Debug build with Signoz wired in: mirror to console for calibration.
  return CompositeLoggerService([console, signoz]);
}

/// Ergonomic facade consumed by usecases / UI / `main.dart`.
///
/// The dynamic context resolver reads identity providers via `ref.read`
/// — **not** `ref.watch` — at every log emission. Two consequences:
///
/// - The logger instance is stable across login/logout/profile-switch.
///   Rebuilding it on every session transition would tear down the
///   Signoz batch buffer and lose in-flight records.
/// - Each emitted record carries the **current** identity. A log emitted
///   right after `selectProfile` already has the new `profile.id`.
///
/// Attributes shipped to Signoz when applicable:
///
/// | Key          | Source                          | When present              |
/// |--------------|---------------------------------|---------------------------|
/// | `device.id`  | `Session.device.id` (server-issued UUID) | once authenticated |
/// | `profile.id` | `currentProfileIdProvider`      | once a profile is active  |
///
/// `user.id` is intentionally omitted: the domain `Session` model does
/// not expose a user identifier (the JWT is opaque on the client side).
/// `device.id` is the per-account stable identifier and is the same one
/// already used as the `X-Device-Id` HTTP header, so backend logs and
/// Signoz logs can be cross-referenced on it.
@Riverpod(keepAlive: true)
LoggerApplicationService logger(Ref ref) {
  return LoggerApplicationService(
    ref.watch(loggerServiceProvider),
    resolveContext: () {
      final session = ref.read(currentSessionProvider);
      final profileId = ref.read(currentProfileIdProvider);
      return <String, Object?>{
        'device.id': ?session?.device.id,
        'profile.id': ?profileId,
      };
    },
  );
}

Map<String, Object?> _resourceAttributes() {
  String env;
  if (_kEnvOverride.isNotEmpty) {
    env = _kEnvOverride;
  } else {
    env = kReleaseMode ? 'production' : 'development';
  }
  return {
    'service.name': 'kidflix',
    'service.version': _kAppVersion,
    'deployment.environment': env,
    'os.type': _osType(),
  };
}

String _osType() {
  // `Platform` is unavailable on web; Kidflix targets mobile/desktop so
  // this is safe today, but we keep the catch defensively in case the
  // web target gets enabled.
  try {
    return Platform.operatingSystem;
  } catch (_) {
    return 'unknown';
  }
}
