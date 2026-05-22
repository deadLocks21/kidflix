import 'package:kidflix/core/domain/model/log_level.dart';
import 'package:kidflix/core/domain/services/logger.service.dart';

/// Ergonomic facade over a [LoggerService].
///
/// Two reasons it exists rather than callers using [LoggerService]
/// directly:
///
/// 1. **Sugar** — `logger.info('foo')` reads better than
///    `logger.log(LogLevel.info, 'foo')`, and keeps usecase code clean.
/// 2. **Context propagation** — every emitted record is enriched with a
///    bag of contextual attributes (e.g. `device.id`, `profile.id`,
///    `video.id`) merged with whatever the call site provides. Call
///    sites only carry domain-specific keys; cross-cutting context is
///    centralized here.
///
/// ## Three layers of context
///
/// At emission time, attributes are merged in this order (later layers
/// override earlier ones on key collision):
///
/// 1. **Dynamic context** — produced by [resolveContext], a callback
///    that returns *current* identity attributes (active session,
///    profile, route, …). Re-evaluated on every emission so the logger
///    instance stays stable across login/logout/profile-switch
///    transitions. Wired up by the provider; the application layer
///    itself stays Riverpod-free.
/// 2. **Static context** — attributes attached via [withContext], used
///    to scope all logs inside a unit of work (e.g. a playback session
///    tagging every log with `video.id`).
/// 3. **Call-site attrs** — what the caller passes to `info`/`error`/…
///    Most specific, always wins.
class LoggerApplicationService {
  final LoggerService _logger;
  final Map<String, Object?> _staticContext;
  final Map<String, Object?> Function()? _resolveContext;

  const LoggerApplicationService(
    this._logger, {
    Map<String, Object?> context = const {},
    Map<String, Object?> Function()? resolveContext,
  }) : _staticContext = context,
       _resolveContext = resolveContext;

  /// Returns a new facade that adds [extra] on top of the current static
  /// context. The dynamic [resolveContext] is preserved as-is.
  LoggerApplicationService withContext(Map<String, Object?> extra) {
    if (extra.isEmpty) return this;
    return LoggerApplicationService(
      _logger,
      context: {..._staticContext, ...extra},
      resolveContext: _resolveContext,
    );
  }

  Future<void> debug(String message, {Map<String, Object?> attrs = const {}}) =>
      _emit(LogLevel.debug, message, attrs: attrs);

  Future<void> info(String message, {Map<String, Object?> attrs = const {}}) =>
      _emit(LogLevel.info, message, attrs: attrs);

  Future<void> warn(
    String message, {
    Map<String, Object?> attrs = const {},
    Object? error,
    StackTrace? stack,
  }) => _emit(LogLevel.warn, message, attrs: attrs, error: error, stack: stack);

  Future<void> error(
    String message, {
    Map<String, Object?> attrs = const {},
    Object? error,
    StackTrace? stack,
  }) =>
      _emit(LogLevel.error, message, attrs: attrs, error: error, stack: stack);

  /// Flushes the underlying service. Call from app lifecycle hooks
  /// (pause / dispose) so the in-flight buffer is shipped before the OS
  /// suspends the process.
  Future<void> flush() => _logger.flush();

  Future<void> _emit(
    LogLevel level,
    String message, {
    required Map<String, Object?> attrs,
    Object? error,
    StackTrace? stack,
  }) {
    // Resolver throws are swallowed: identity must never sink a log.
    Map<String, Object?> dynamic_;
    try {
      dynamic_ = _resolveContext?.call() ?? const {};
    } catch (_) {
      dynamic_ = const {};
    }
    final merged = (dynamic_.isEmpty && _staticContext.isEmpty && attrs.isEmpty)
        ? const <String, Object?>{}
        : <String, Object?>{...dynamic_, ..._staticContext, ...attrs};
    return _logger.log(
      level,
      message,
      attributes: merged,
      error: error,
      stack: stack,
    );
  }
}
