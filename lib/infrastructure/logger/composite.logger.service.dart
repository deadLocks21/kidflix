import 'package:kidflix/core/domain/model/log_level.dart';
import 'package:kidflix/core/domain/services/logger.service.dart';

/// Fans out every log record to a list of [LoggerService]s.
///
/// Primary use case: in debug builds that have a Signoz key configured,
/// wrap both the [ConsoleLoggerService] and the [SignozLoggerService] so
/// the developer sees in their console *exactly* what is shipped over
/// the network. Removes the gap between "what I see locally" and "what
/// lands in Signoz".
///
/// Calls into the children are sequential (`await` each) — the volume
/// is low enough that fan-out parallelism would be premature, and
/// sequential calls make the order in the console deterministic.
///
/// If a child throws (which it shouldn't per [LoggerService] contract,
/// but defensively), the error is swallowed so a faulty adapter cannot
/// take the others down.
class CompositeLoggerService implements LoggerService {
  final List<LoggerService> _children;

  CompositeLoggerService(List<LoggerService> children)
    : assert(
        children.isNotEmpty,
        'CompositeLoggerService needs at least one child',
      ),
      _children = List.unmodifiable(children);

  @override
  Future<void> log(
    LogLevel level,
    String message, {
    Map<String, Object?> attributes = const {},
    Object? error,
    StackTrace? stack,
  }) async {
    for (final child in _children) {
      try {
        await child.log(
          level,
          message,
          attributes: attributes,
          error: error,
          stack: stack,
        );
      } catch (_) {
        // Swallow — one bad adapter must not silence the others.
      }
    }
  }

  @override
  Future<void> flush() async {
    for (final child in _children) {
      try {
        await child.flush();
      } catch (_) {
        // See above.
      }
    }
  }
}
