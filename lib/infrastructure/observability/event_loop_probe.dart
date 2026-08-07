import 'dart:async';

/// Measures how late the main isolate runs work it was asked to run on
/// time.
///
/// A periodic timer set to [interval] that actually fires 900 ms late
/// means the isolate was busy for 900 ms — and *everything* queued on it
/// during that window waited too.
///
/// ## Why this exists next to `http.call`
///
/// `TimingInterceptor.duration_ms` is measured between two Dio
/// callbacks, and both run on the main isolate. It is therefore
/// "dispatch → callback executed", not "time on the wire". The two are
/// the same number on an idle app and wildly different during startup,
/// where engine warm-up, plugin registration, preference reads and mDNS
/// advertising all compete for the isolate.
///
/// Without this probe there is no way to tell a slow server from a busy
/// client: three tiny requests that all report ~2.2 s and complete
/// within 6 ms of each other look like a network problem and are not
/// one. Reading `startup.jank` alongside them settles it.
class EventLoopProbe {
  EventLoopProbe({this.interval = const Duration(milliseconds: 16)});

  /// How often the probe asks to be woken. Small enough to catch a stall
  /// precisely, large enough not to be the jank it measures.
  final Duration interval;

  Timer? _timer;
  final Stopwatch _clock = Stopwatch();
  int _lastTickMs = 0;
  int _maxLagMs = 0;
  int _maxLagAtMs = 0;
  int _totalLagMs = 0;
  int _samples = 0;
  int _stalls = 0;

  /// A tick this late means a frame was missed outright — the threshold
  /// for counting a stall rather than ordinary scheduling noise.
  static const _stallThresholdMs = 100;

  void start() {
    if (_timer != null) return;
    _clock.start();
    _lastTickMs = _clock.elapsedMilliseconds;
    _timer = Timer.periodic(interval, (_) {
      final now = _clock.elapsedMilliseconds;
      final lag = now - _lastTickMs - interval.inMilliseconds;
      _lastTickMs = now;
      _samples++;
      if (lag <= 0) return;
      _totalLagMs += lag;
      if (lag > _maxLagMs) {
        _maxLagMs = lag;
        _maxLagAtMs = now;
      }
      if (lag >= _stallThresholdMs) _stalls++;
    });
  }

  /// Stops sampling and returns the summary as log attributes.
  ///
  /// `max_lag_ms` is the headline: it is the longest single stretch the
  /// isolate spent unable to run anything. Any `http.call` overlapping
  /// that stretch is inflated by up to that much.
  Map<String, Object?> stop() {
    _timer?.cancel();
    _timer = null;
    _clock.stop();
    return {
      'max_lag_ms': _maxLagMs,
      // When the worst stall ENDED, measured from probe start. Lines it
      // up against the startup phase timings.
      'max_lag_at_ms': _maxLagAtMs,
      'total_lag_ms': _totalLagMs,
      'stalls': _stalls,
      'samples': _samples,
      'window_ms': _clock.elapsedMilliseconds,
    };
  }
}
