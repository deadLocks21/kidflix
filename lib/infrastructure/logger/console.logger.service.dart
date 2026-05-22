import 'dart:developer' as developer;

import 'package:kidflix/core/domain/model/log_level.dart';
import 'package:kidflix/core/domain/services/logger.service.dart';

/// [LoggerService] that prints to the dev console via `dart:developer`'s
/// `log()`.
///
/// Used:
/// - In every non-release build as the primary sink.
/// - As one branch of [CompositeLoggerService] so the developer can see
///   in their console exactly what is being shipped to Signoz (for
///   calibration).
///
/// The output is a single line per record: `LEVEL message k=v k=v …`
/// followed by a stack trace when present. Cheap and grep-friendly.
///
/// Has no buffer — `flush()` is a no-op.
class ConsoleLoggerService implements LoggerService {
  /// Optional tag prefixed to the message. Useful to distinguish records
  /// that *also* went to Signoz when this service is wrapped in a
  /// [CompositeLoggerService] (e.g. `[→signoz]`).
  final String? prefix;

  /// `dart:developer` logger name. Shows up in Flutter DevTools' Logging
  /// view as the category.
  final String name;

  const ConsoleLoggerService({this.prefix, this.name = 'kidflix'});

  @override
  Future<void> log(
    LogLevel level,
    String message, {
    Map<String, Object?> attributes = const {},
    Object? error,
    StackTrace? stack,
  }) async {
    final buf = StringBuffer();
    if (prefix != null) buf.write('$prefix ');
    buf.write(message);
    if (attributes.isNotEmpty) {
      buf.write(' ');
      buf.writeAll(
        attributes.entries.map((e) => '${e.key}=${_format(e.value)}'),
        ' ',
      );
    }
    developer.log(
      buf.toString(),
      name: name,
      level:
          level.otelSeverityNumber * 100, // dart:developer expects 0..2000-ish
      error: error,
      stackTrace: stack,
    );
  }

  @override
  Future<void> flush() async {}

  String _format(Object? v) {
    if (v == null) return 'null';
    if (v is String) {
      // Quote only if the value contains whitespace, otherwise the line
      // stays maximally grep-friendly.
      return v.contains(RegExp(r'\s')) ? '"$v"' : v;
    }
    return v.toString();
  }
}
