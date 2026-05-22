import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:dio/dio.dart';
import 'package:kidflix/core/domain/model/log_level.dart';
import 'package:kidflix/core/domain/services/logger.service.dart';

/// Ships log records to a Signoz instance via OTLP/HTTP.
///
/// Wire format: OpenTelemetry's `ExportLogsServiceRequest` JSON payload,
/// posted to `<ingest base>/v1/logs`. Signaz accepts the protobuf JSON
/// encoding natively, so no SDK is required — a hand-rolled body is
/// lighter than pulling in `opentelemetry` + `opentelemetry_exporter_otlp_http`
/// which are still rough around the edges on Dart.
///
/// ## Resource attributes
///
/// Every batch is tagged with the [resourceAttributes] passed at
/// construction (service.name, service.version, deployment.environment,
/// os.type, …). They appear as `resource.*` columns in Signoz and are
/// the recommended way to slice dashboards.
///
/// ## Batching
///
/// Records are accumulated in an in-memory list and flushed:
/// - When [maxBatchSize] is reached, immediately.
/// - Otherwise every [flushInterval], by a periodic timer.
/// - On explicit [flush] (called from app lifecycle hooks).
///
/// The list is capped at [maxQueueSize] to avoid unbounded growth when
/// the network stays down — old records are dropped first.
///
/// ## Failure mode
///
/// Network errors are caught and logged via `dart:developer` (not via
/// `LoggerService`, to avoid recursion). The dropped batch is *not*
/// retried — telemetry is best-effort, and a retry queue would risk
/// piling up duplicate records on transient failures. If you find this
/// too aggressive, the easiest evolution is to keep the failing batch
/// at the head of the buffer and try again on the next flush tick.
class SignozLoggerService implements LoggerService {
  /// Full OTLP HTTP logs endpoint, e.g.
  /// `https://ingest.eu.signoz.cloud:443/v1/logs` (Signoz Cloud) or
  /// `http://10.0.2.2:4318/v1/logs` (Android emulator → host
  /// self-hosted Signoz collector).
  final String endpoint;

  /// Cloud ingestion key. Sent as `signoz-access-token` header.
  /// `null`/empty for self-hosted deployments without auth.
  final String? ingestionKey;

  /// OTLP resource attributes attached to every batch.
  final Map<String, Object?> resourceAttributes;

  final Dio _dio;
  final Duration flushInterval;
  final int maxBatchSize;
  final int maxQueueSize;

  final List<_PendingRecord> _buffer = [];
  Timer? _timer;
  bool _disposed = false;
  Future<void>? _inflight;

  SignozLoggerService({
    required this.endpoint,
    this.ingestionKey,
    this.resourceAttributes = const {},
    this.flushInterval = const Duration(seconds: 10),
    this.maxBatchSize = 50,
    this.maxQueueSize = 500,
    Dio? dio,
  }) : _dio =
           dio ??
           Dio(
             BaseOptions(
               connectTimeout: const Duration(seconds: 5),
               sendTimeout: const Duration(seconds: 10),
               receiveTimeout: const Duration(seconds: 10),
               contentType: 'application/json',
               responseType: ResponseType.plain,
             ),
           ) {
    _timer = Timer.periodic(flushInterval, (_) => unawaited(flush()));
  }

  @override
  Future<void> log(
    LogLevel level,
    String message, {
    Map<String, Object?> attributes = const {},
    Object? error,
    StackTrace? stack,
  }) async {
    if (_disposed) return;
    // Drop oldest if full — newest data is more useful than ancient.
    if (_buffer.length >= maxQueueSize) {
      _buffer.removeAt(0);
    }
    _buffer.add(
      _PendingRecord(
        timestampNanos: _nowUnixNano(),
        level: level,
        message: message,
        attributes: attributes,
        error: error,
        stack: stack,
      ),
    );
    if (_buffer.length >= maxBatchSize) {
      unawaited(flush());
    }
  }

  @override
  Future<void> flush() async {
    // Coalesce concurrent flushes — only one ship-out at a time.
    if (_inflight != null) return _inflight;
    if (_buffer.isEmpty) return;
    final batch = List<_PendingRecord>.from(_buffer);
    _buffer.clear();
    final future = _ship(batch);
    _inflight = future;
    try {
      await future;
    } finally {
      _inflight = null;
    }
  }

  Future<void> _ship(List<_PendingRecord> batch) async {
    try {
      await _dio.post<dynamic>(
        endpoint,
        data: jsonEncode(_buildPayload(batch)),
        options: Options(
          headers: {
            if (ingestionKey != null && ingestionKey!.isNotEmpty)
              'signoz-access-token': ingestionKey,
          },
        ),
      );
    } catch (e, st) {
      // Never throw — telemetry must not crash the app. Surface to
      // dev console (not to LoggerService, that would recurse).
      developer.log(
        'signoz: failed to ship batch of ${batch.length} record(s) — dropping',
        name: 'kidflix.logger',
        level: 900,
        error: e,
        stackTrace: st,
      );
    }
  }

  Map<String, dynamic> _buildPayload(List<_PendingRecord> batch) {
    return {
      'resourceLogs': [
        {
          'resource': {'attributes': _otlpAttributes(resourceAttributes)},
          'scopeLogs': [
            {
              'scope': {'name': 'kidflix.app'},
              'logRecords': batch.map(_otlpRecord).toList(growable: false),
            },
          ],
        },
      ],
    };
  }

  Map<String, dynamic> _otlpRecord(_PendingRecord r) {
    final attrs = <String, Object?>{...r.attributes};
    if (r.error != null) {
      attrs['exception.type'] = r.error.runtimeType.toString();
      attrs['exception.message'] = r.error.toString();
    }
    if (r.stack != null) {
      attrs['exception.stacktrace'] = r.stack.toString();
    }
    return {
      'timeUnixNano': r.timestampNanos.toString(),
      'severityNumber': r.level.otelSeverityNumber,
      'severityText': r.level.otelSeverityText,
      'body': {'stringValue': r.message},
      'attributes': _otlpAttributes(attrs),
    };
  }

  /// Encodes a flat map into the OTLP `KeyValue[]` shape Signoz expects.
  /// Unknown types are coerced via `toString()` rather than dropped, so
  /// the caller always sees *something* in Signoz.
  List<Map<String, dynamic>> _otlpAttributes(Map<String, Object?> map) {
    final out = <Map<String, dynamic>>[];
    for (final e in map.entries) {
      final value = e.value;
      Map<String, dynamic> wrapped;
      if (value == null) {
        // OTLP has no explicit null — encode as empty string so the key
        // is still indexed.
        wrapped = {'stringValue': ''};
      } else if (value is String) {
        wrapped = {'stringValue': value};
      } else if (value is bool) {
        wrapped = {'boolValue': value};
      } else if (value is int) {
        wrapped = {'intValue': value.toString()};
      } else if (value is double) {
        wrapped = {'doubleValue': value};
      } else {
        wrapped = {'stringValue': value.toString()};
      }
      out.add({'key': e.key, 'value': wrapped});
    }
    return out;
  }

  int _nowUnixNano() => DateTime.now().microsecondsSinceEpoch * 1000;

  /// Stops the periodic flush and ships whatever is buffered. Tests /
  /// hot-reload paths only.
  Future<void> dispose() async {
    _disposed = true;
    _timer?.cancel();
    _timer = null;
    await flush();
    _dio.close(force: true);
  }
}

class _PendingRecord {
  final int timestampNanos;
  final LogLevel level;
  final String message;
  final Map<String, Object?> attributes;
  final Object? error;
  final StackTrace? stack;

  _PendingRecord({
    required this.timestampNanos,
    required this.level,
    required this.message,
    required this.attributes,
    this.error,
    this.stack,
  });
}
