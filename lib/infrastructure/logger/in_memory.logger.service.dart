import 'package:kidflix/core/domain/model/log_level.dart';
import 'package:kidflix/core/domain/services/logger.service.dart';

/// Test-only [LoggerService] that records every entry into an in-memory
/// list. Mirrors the `InMemory*Repository` pattern used elsewhere in
/// `lib/infrastructure/`.
///
/// Not wired into the production provider — tests that need to assert on
/// logs construct it directly:
///
/// ```dart
/// final logger = InMemoryLoggerService();
/// await myUseCase.run();
/// expect(logger.records.last.message, equals('playback.started'));
/// ```
class InMemoryLoggerService implements LoggerService {
  final List<LoggedRecord> records = [];

  @override
  Future<void> log(
    LogLevel level,
    String message, {
    Map<String, Object?> attributes = const {},
    Object? error,
    StackTrace? stack,
  }) async {
    records.add(
      LoggedRecord(
        level: level,
        message: message,
        attributes: Map.unmodifiable(attributes),
        error: error,
        stack: stack,
      ),
    );
  }

  @override
  Future<void> flush() async {}

  /// Discards every recorded entry. Useful between test cases.
  void clear() => records.clear();
}

/// One log entry captured by [InMemoryLoggerService].
class LoggedRecord {
  final LogLevel level;
  final String message;
  final Map<String, Object?> attributes;
  final Object? error;
  final StackTrace? stack;

  const LoggedRecord({
    required this.level,
    required this.message,
    required this.attributes,
    this.error,
    this.stack,
  });
}
