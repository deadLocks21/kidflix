import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:kidflix/core/application/services/logger_application.service.dart';

/// Logs one record per HTTP call with its **client-side** duration.
///
/// The backend already logs its own `duration_ms`, but that only covers
/// handler time. What a slow screen is actually made of — DNS, TLS,
/// connection reuse, uplink latency, transfer of the body, and JSON
/// decoding — lives entirely in the gap between the two numbers. Having
/// both sides lets that gap be read directly.
///
/// Emitted at debug level and installed only when [kPerfTrace] is on
/// (the caller decides), because nothing downstream filters by level.
///
/// The `bytes` attribute is the decoded payload size, not the number of
/// bytes on the wire: Dio hands over an already-parsed body and the
/// response is very likely gzipped in transit. It is the right number
/// for "how much JSON did we make the client chew through", and an
/// over-estimate of network cost.
class TimingInterceptor extends Interceptor {
  final LoggerApplicationService _logger;

  TimingInterceptor(this._logger);

  static const _startKey = 'perf_trace_start';

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.extra[_startKey] = Stopwatch()..start();
    handler.next(options);
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    _emit(
      options: response.requestOptions,
      status: response.statusCode,
      data: response.data,
      error: null,
    );
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    _emit(
      options: err.requestOptions,
      status: err.response?.statusCode,
      data: err.response?.data,
      error: err.type.name,
    );
    handler.next(err);
  }

  void _emit({
    required RequestOptions options,
    required int? status,
    required Object? data,
    required String? error,
  }) {
    final sw = options.extra[_startKey];
    if (sw is! Stopwatch) return;
    sw.stop();
    // Fire-and-forget: instrumentation must never add latency to the
    // call it is measuring, nor fail it.
    _logger.debug(
      'http.call',
      attrs: {
        'http.method': options.method,
        'http.path': options.path,
        'http.status': status,
        'duration_ms': sw.elapsedMilliseconds,
        'bytes': _sizeOf(data),
        'http.error': ?error,
      },
    );
  }

  /// Best-effort payload size. Re-encoding a large map is not free, which
  /// is precisely why this only runs under the perf-trace flag.
  int? _sizeOf(Object? data) {
    if (data == null) return null;
    if (data is String) return data.length;
    if (data is List<int>) return data.length;
    try {
      return jsonEncode(data).length;
    } catch (_) {
      return null;
    }
  }
}
