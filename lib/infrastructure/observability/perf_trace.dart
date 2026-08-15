import 'package:flutter/foundation.dart' show kDebugMode;

/// Opt-in instrumentation used to find out where the wall-clock of a
/// screen actually goes.
///
/// Why a flag rather than always-on: nothing in the logging stack
/// filters by level (`SignozLoggerService` ships every record it is
/// given), so a per-HTTP-request log line would be shipped from every
/// production device. The per-request detail is a diagnostic tool, not
/// permanent telemetry.
///
/// Defaults to on in debug builds, which is the case that matters —
/// running locally against the production backend. Force it either way
/// with `--dart-define=PERF_TRACE=true|false`.
const bool kPerfTrace = bool.fromEnvironment(
  'PERF_TRACE',
  defaultValue: kDebugMode,
);

/// Accumulates named phase durations for one unit of work, then hands
/// them over as a flat attribute map ready for a single log record.
///
/// One line per home load beats one line per phase: the phases are only
/// meaningful relative to each other and to the total, and a single
/// record keeps them on one row in Signoz instead of forcing a join.
///
/// ```dart
/// final trace = PerfTrace();
/// final items = await trace.measure('catalog', () => repo.listCatalog());
/// …
/// logger.info('home.load', attrs: trace.attrs());
/// ```
class PerfTrace {
  final Stopwatch _total = Stopwatch()..start();
  final Map<String, int> _phases = {};

  /// Runs [body], recording how long it took under `<name>_ms`.
  ///
  /// Re-using a name accumulates rather than overwrites, so a phase that
  /// runs in a loop reports its total cost. The duration is recorded even
  /// when [body] throws — a failing phase is exactly the one worth
  /// timing — and the error is rethrown untouched.
  Future<T> measure<T>(String name, Future<T> Function() body) async {
    final sw = Stopwatch()..start();
    try {
      return await body();
    } finally {
      sw.stop();
      _phases['${name}_ms'] =
          (_phases['${name}_ms'] ?? 0) + sw.elapsedMilliseconds;
    }
  }

  /// Records a phase measured by the caller, for the cases `measure`
  /// cannot wrap (a value already awaited, a synchronous block).
  void record(String name, Duration elapsed) {
    _phases['${name}_ms'] =
        (_phases['${name}_ms'] ?? 0) + elapsed.inMilliseconds;
  }

  /// Attaches an arbitrary counter — item counts, byte totals, anything
  /// that helps read the durations.
  void count(String name, num value) => _phases[name] = value.round();

  /// Phase durations plus `total_ms`, measured from construction.
  ///
  /// `total_ms` is deliberately not the sum of the phases: the gap
  /// between them is the interesting part (framework overhead, work
  /// nobody thought to instrument).
  Map<String, Object?> attrs() => {
    ..._phases,
    'total_ms': _total.elapsedMilliseconds,
  };
}
