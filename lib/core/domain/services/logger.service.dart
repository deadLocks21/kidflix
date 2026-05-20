import 'package:kidflix/core/domain/model/log_level.dart';

/// Contract for emitting application log records.
///
/// Domain port for the logging concern. Implementations live in
/// `lib/infrastructure/logger/`:
///
/// - `ConsoleLoggerService`  — prints to the dev console.
/// - `SignozLoggerService`   — ships OTLP/HTTP logs to Signoz.
/// - `CompositeLoggerService`— fans out to several services at once
///   (used to mirror Signoz traffic into the dev console during
///   calibration).
/// - `InMemoryLoggerService` — captures records for tests.
///
/// The contract is intentionally tiny: a single async sink. Higher-level
/// ergonomics (`info`, `error`, automatic context attributes…) live in
/// the application layer (`LoggerApplicationService`) so the port stays
/// stable across providers.
///
/// `attributes` are arbitrary key/value pairs attached to the record.
/// Adapters serialise them according to their target format (OTLP for
/// Signoz, key=value lines for the console, …). Values must be JSON-
/// serialisable primitives — `String`, `num`, `bool`, or `null`. Anything
/// else is coerced via `toString()` by the adapter.
///
/// Implementations MUST NOT throw. A logger that fails to log must
/// degrade silently (the rest of the app should not crash because
/// telemetry is unavailable).
abstract interface class LoggerService {
  /// Records a single log entry.
  ///
  /// [message] is the human-readable summary. Keep it short and stable
  /// (good: `playback.failed`; bad: `Could not play video xyz at 10:42`).
  /// Variable data belongs in [attributes].
  ///
  /// [error] / [stack] are optional and used when [level] is
  /// [LogLevel.error] (or occasionally [LogLevel.warn]) to capture the
  /// exception type and stack trace alongside the message.
  Future<void> log(
    LogLevel level,
    String message, {
    Map<String, Object?> attributes,
    Object? error,
    StackTrace? stack,
  });

  /// Flushes any in-flight buffer. Called on app pause/dispose so logs
  /// emitted right before backgrounding are not lost. No-op for adapters
  /// that don't buffer.
  Future<void> flush();
}
