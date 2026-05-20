// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'logger.service_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
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

@ProviderFor(loggerService)
final loggerServiceProvider = LoggerServiceProvider._();

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

final class LoggerServiceProvider
    extends $FunctionalProvider<LoggerService, LoggerService, LoggerService>
    with $Provider<LoggerService> {
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
  LoggerServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'loggerServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$loggerServiceHash();

  @$internal
  @override
  $ProviderElement<LoggerService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  LoggerService create(Ref ref) {
    return loggerService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(LoggerService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<LoggerService>(value),
    );
  }
}

String _$loggerServiceHash() => r'd4776e190e5d6bf22bee8a513efc6e7be48c7fbd';

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

@ProviderFor(logger)
final loggerProvider = LoggerProvider._();

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

final class LoggerProvider
    extends
        $FunctionalProvider<
          LoggerApplicationService,
          LoggerApplicationService,
          LoggerApplicationService
        >
    with $Provider<LoggerApplicationService> {
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
  LoggerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'loggerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$loggerHash();

  @$internal
  @override
  $ProviderElement<LoggerApplicationService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  LoggerApplicationService create(Ref ref) {
    return logger(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(LoggerApplicationService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<LoggerApplicationService>(value),
    );
  }
}

String _$loggerHash() => r'6ac601de31540196a567cec9f8f88cd35f222784';
