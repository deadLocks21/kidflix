import 'dart:async';
import 'dart:io' show exit;

import 'dart:ui' show FramePhase;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:media_kit/media_kit.dart';

/// Console-only instrumentation answering one question: when playback
/// "lags", *what* is lagging?
///
/// Four unrelated failures all look identical from the couch — the film
/// stutters — and the fix for each is somewhere else entirely:
///
/// * **starving** — mpv has no data to decode (file still downloading,
///   slow storage). Shows up as `rebuffer` events, nothing else.
/// * **decoding** — the decoder cannot produce frames fast enough.
///   Shows up as `drop_dec`. Usually means the hardware decoder is not
///   the one you think: check `hwdec` on the `open` line.
/// * **presenting** — the decoder keeps up but the frames are not put on
///   screen in time. Shows up as `drop_vo` with `drop_dec` at zero, and
///   splits further: `raster_ms` high means the compositor is the
///   bottleneck, `raster_ms` low means it is a frame-pacing problem
///   between mpv and the host's vsync.
/// * **UI jank** — the video texture is fine, the Flutter isolate is
///   not. Shows up as `jank_ms`, with the video counters clean.
/// * **contention** — the download is competing for IO/CPU with the
///   decoder. Shows up as any of the above, but only while a download
///   is in flight.
///
/// `gap_ms` sits above all four: it is how much wall-clock the film
/// failed to advance during the window, i.e. what the viewer actually
/// perceives, whatever the cause. A window with a large `gap_ms` and no
/// other counter moving means the cause is none of the four and worth a
/// closer look.
///
/// One negative result worth not repeating: giving mpv the real refresh
/// rate (`override-display-fps`) together with
/// `video-sync=display-resample` makes presentation dramatically *worse*
/// — mpv then tries to render at the display cadence, the host still
/// collects frames at its own rate, and the A/V sync collapses outright
/// (measured: `frames` down to ~3/s, `avsync` past 1 s). With
/// `vo=libmpv` the host owns the frame clock, and mpv must not be told
/// otherwise.
///
/// Output goes to `debugPrint` and nowhere else — this is a local
/// debugging aid, not telemetry, so it is gated on [kPerfTrace] (debug
/// builds by default, forceable with `--dart-define=PERF_TRACE=`).
class PlaybackDiagnostics {
  PlaybackDiagnostics(this._player);

  final Player _player;

  /// How often a sample line is printed. Long enough that a single
  /// hiccup does not drown in the average, short enough to line up
  /// against what the viewer just saw.
  static const _window = Duration(seconds: 5);

  Timer? _timer;
  StreamSubscription<bool>? _bufferingSub;
  StreamSubscription<bool>? _playingSub;

  EventLoopProbe? _probe;

  /// Wall-clock, but only while the player believes it is playing —
  /// otherwise every pause would register as a giant stall.
  final Stopwatch _playingClock = Stopwatch();
  final Stopwatch _bufferingClock = Stopwatch();

  /// Seconds of playback to measure before printing a verdict and
  /// quitting, for `tools/playback_bench.sh`. Zero (the default) means
  /// "never quit", i.e. the ordinary interactive behaviour.
  ///
  /// The app ends its own run rather than letting the harness kill it:
  /// a script that waits a fixed wall-clock time and then sends a signal
  /// has to guess how long start-up took, and would cut some runs short
  /// and let others measure a paused player.
  static const _probeDurationS = int.fromEnvironment('PROBE_DURATION_S');

  /// Windows kept for the verdict, oldest first. `w=0` is excluded by
  /// the harness, not here — it is genuinely different (engine warm-up,
  /// first demux) and averaging it in would flatter or damn a run
  /// depending only on how fast the file opened.
  final List<int> _dropHistory = [];
  final List<int> _paceOffPctHistory = [];

  Duration _lastPosition = Duration.zero;
  int _lastPlayingMs = 0;
  int _rebuffers = 0;

  /// Frame timings reported by the engine since the last sample.
  ///
  /// [EventLoopProbe] only ever sees the Dart isolate. The video texture
  /// is composited on the raster thread, which can be saturated while
  /// the isolate sits idle — exactly the blind spot that makes a low
  /// `jank_ms` alongside dropped frames ambiguous. These timings close
  /// it: `raster_ms` is the cost of actually putting the frame on
  /// screen.
  final List<FrameTiming> _frames = [];
  int _lastVoDropped = 0;
  int _lastDecDropped = 0;
  int _windows = 0;

  /// Starts sampling. Safe to call on any platform and in any build: a
  /// no-op unless [kPerfTrace] is on.
  void start() {
    if (!kPerfTrace || _timer != null) return;
    _bufferingSub = _player.stream.buffering.listen((buffering) {
      if (buffering) {
        _rebuffers++;
        _bufferingClock.start();
      } else {
        _bufferingClock.stop();
      }
    });
    _playingSub = _player.stream.playing.listen((playing) {
      playing ? _playingClock.start() : _playingClock.stop();
    });
    _probe = EventLoopProbe(
      // Coarser than the probe's own default: at 16 ms the timer wakes
      // up 60 times a second on the very isolate it is measuring, which
      // is enough to become the jank it reports.
      interval: const Duration(milliseconds: 32),
    )..start();
    SchedulerBinding.instance.addTimingsCallback(_onFrameTimings);
    _timer = Timer.periodic(_window, (_) => _sample());
  }

  /// Prints the one-off facts about the media that explain most of what
  /// the samples will show. Call right after the engine opens a file.
  ///
  /// Polls rather than reading once. `Player.open` returns as soon as
  /// the playlist entry is queued — the decoder has not picked a backend
  /// yet, so every property here reads back as the empty string and the
  /// line prints with nothing in it. `hwdec-current` is the last of them
  /// to resolve, so it doubles as the readiness signal.
  Future<void> logMediaOpened() async {
    if (!kPerfTrace) return;
    var props = const <String, String>{};
    for (var attempt = 0; attempt < 25; attempt++) {
      props = await _readProperties([
        'hwdec-current',
        'video-codec',
        'video-params/pixelformat',
        'width',
        'height',
        'container-fps',
        'audio-codec-name',
        // The renderer, as distinct from the decoder. A file that
        // decodes on the GPU can still be presented through a slow path.
        'current-vo',
        'display-fps',
      ]);
      final hwdec = props['hwdec-current'] ?? '';
      if (hwdec.isNotEmpty && hwdec != 'no') break;
      // `no` is a legitimate final answer, not just an unresolved one —
      // keep polling a little in case it resolves later, but do not let
      // a genuinely software-decoded file block the line forever.
      if (hwdec == 'no' && attempt > 5) break;
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
    debugPrint(
      '[kidflix.playback] open '
      'hwdec=${props['hwdec-current']} '
      'vo=${props['current-vo']} '
      'codec=${props['video-codec']} '
      'pixfmt=${props['video-params/pixelformat']} '
      'size=${props['width']}x${props['height']} '
      'fps=${props['container-fps']} '
      'display_fps=${props['display-fps']} '
      // mpv cannot see the screen through `vo=libmpv`, so its own
      // `display-fps` is always blank. Flutter knows, and the ratio
      // between this and the container fps is what decides whether
      // frames can be presented evenly at all.
      'flutter_display_hz=${_flutterRefreshRate()?.toStringAsFixed(1)} '
      'audio=${props['audio-codec-name']}',
    );
  }

  void _onFrameTimings(List<FrameTiming> timings) => _frames.addAll(timings);

  /// The refresh rate of the display the app is currently on, or null
  /// when the platform does not report one (0.0 is the "unknown" value
  /// the embedder uses).
  double? _flutterRefreshRate() {
    final views = WidgetsBinding.instance.platformDispatcher.views;
    if (views.isEmpty) return null;
    final rate = views.first.display.refreshRate;
    return rate > 0 ? rate : null;
  }

  Future<void> _sample() async {
    final playingMs = _playingClock.elapsedMilliseconds;
    final elapsedMs = playingMs - _lastPlayingMs;
    _lastPlayingMs = playingMs;

    final position = _player.state.position;
    final advancedMs = (position - _lastPosition).inMilliseconds;
    _lastPosition = position;

    final jank = _probe?.stop() ?? const <String, Object?>{};
    _probe = EventLoopProbe(interval: const Duration(milliseconds: 32))
      ..start();

    final rebuffers = _rebuffers;
    _rebuffers = 0;
    final bufferingMs = _bufferingClock.elapsedMilliseconds;
    _bufferingClock.reset();
    // A stopwatch stopped by `reset` forgets it was running; re-arm it
    // so a rebuffer spanning two windows keeps being counted.
    if (_player.state.buffering) _bufferingClock.start();

    // Presenting at 60 Hz leaves 16.7 ms per frame for build + raster
    // combined; a frame over that budget is one the compositor missed.
    const frameBudgetMs = 16;
    var maxBuildMs = 0;
    var maxRasterMs = 0;
    var slowFrames = 0;
    for (final f in _frames) {
      final build = f.buildDuration.inMilliseconds;
      final raster = f.rasterDuration.inMilliseconds;
      if (build > maxBuildMs) maxBuildMs = build;
      if (raster > maxRasterMs) maxRasterMs = raster;
      if (f.totalSpan.inMilliseconds > frameBudgetMs) slowFrames++;
    }
    final frameCount = _frames.length;

    // Frame pacing — the metric everything else missed.
    //
    // A 24 fps film on a 120 Hz screen needs every image held for
    // exactly 5 refreshes. An image held for 4 or 6 is on time by every
    // measure Flutter reports (its frame met the budget, its vsync was
    // not late) and still lands visibly early or late on screen. Judder
    // is entirely invisible to `build_ms`, `raster_ms` and `jank_ms`,
    // and DevTools shows a clean timeline while the film stutters.
    final hz = _flutterRefreshRate();
    var paced = 0;
    var offBeat = 0;
    if (hz != null && _frames.length > 2) {
      final refreshUs = 1000000 / hz;
      final starts = [
        for (final f in _frames)
          f.timestampInMicroseconds(FramePhase.vsyncStart),
      ]..sort();
      final holds = <int>[];
      for (var i = 0; i < starts.length - 1; i++) {
        final delta = starts[i + 1] - starts[i];
        // Ignore anything outside plausible playback spacing: idle
        // stretches and UI animation bursts are not the film's cadence.
        if (delta < refreshUs * 2 || delta > refreshUs * 12) continue;
        holds.add((delta / refreshUs).round());
      }
      if (holds.isNotEmpty) {
        // The modal hold IS the expected cadence — derived rather than
        // assumed, so this stays correct for a 25 or 30 fps file, and on
        // a 60 Hz screen, without knowing either in advance.
        final counts = <int, int>{};
        for (final h in holds) {
          counts[h] = (counts[h] ?? 0) + 1;
        }
        var expected = holds.first;
        for (final e in counts.entries) {
          if (e.value > (counts[expected] ?? 0)) expected = e.key;
        }
        paced = counts[expected] ?? 0;
        offBeat = holds.length - paced;
      }
    }
    final offBeatPct = (paced + offBeat) > 0
        ? (100 * offBeat / (paced + offBeat)).round()
        : 0;

    _frames.clear();

    final props = await _readProperties([
      'frame-drop-count',
      'decoder-frame-drop-count',
      'avsync',
      'cache-buffering-state',
    ]);
    // Kept apart, not summed: they point at opposite halves of the
    // pipeline. `decoder-frame-drop-count` means the decoder could not
    // produce frames fast enough — the codec is too heavy for the
    // backend in use. `frame-drop-count` means the decoder kept up but
    // the video output could not present them in time — a rendering /
    // texture-upload / display-sync problem, which on Flutter is a
    // completely different investigation.
    final vo = int.tryParse(props['frame-drop-count'] ?? '') ?? 0;
    final dec = int.tryParse(props['decoder-frame-drop-count'] ?? '') ?? 0;
    final voDelta = vo - _lastVoDropped;
    final decDelta = dec - _lastDecDropped;
    _lastVoDropped = vo;
    _lastDecDropped = dec;

    // Nothing was supposed to be playing during this window — a paused
    // player has nothing to say and a line per 5 s of pause would bury
    // the ones that matter.
    if (elapsedMs < _window.inMilliseconds ~/ 2) return;

    // How much of the window the film failed to advance through. Clamped
    // at zero: position can legitimately jump ahead of wall-clock after
    // a seek, and a negative "gap" is not a thing.
    final gapMs = (elapsedMs - advancedMs).clamp(0, elapsedMs);

    debugPrint(
      '[kidflix.playback] w=${_windows++} '
      'gap_ms=$gapMs '
      'rebuffer=$rebuffers/${bufferingMs}ms '
      'drop_vo=$voDelta drop_dec=$decDelta '
      'jank_ms=${jank['max_lag_ms']} '
      'frames=$frameCount slow=$slowFrames '
      'pace_ok=$paced pace_off=$offBeat ($offBeatPct%) '
      'build_ms=$maxBuildMs raster_ms=$maxRasterMs '
      'stalls=${jank['stalls']} '
      'avsync=${props['avsync']} '
      'cache=${props['cache-buffering-state']}%',
    );

    _dropHistory.add(voDelta);
    _paceOffPctHistory.add(offBeatPct);
    if (_probeDurationS > 0 &&
        playingMs >= _probeDurationS * 1000 &&
        _dropHistory.length > 1) {
      _printVerdict();
    }
  }

  /// Prints the one line the harness parses, then ends the run.
  ///
  /// Medians rather than means: a single ugly window — an overlay
  /// appearing, the OS scheduling something else — would drag a mean far
  /// enough to flip a verdict, and that is precisely the noise that made
  /// hand-run comparisons unreliable.
  void _printVerdict() {
    // `w=0` covers engine warm-up and first demux; it is never
    // representative of steady-state playback.
    final drops = _dropHistory.skip(1).toList()..sort();
    final paces = _paceOffPctHistory.skip(1).toList()..sort();
    if (drops.isEmpty) return;
    int median(List<int> xs) => xs[xs.length ~/ 2];
    final worst = drops.last;
    final dirty = drops.where((d) => d > 0).length;
    debugPrint(
      '[kidflix.probe] windows=${drops.length} '
      'drop_median=${median(drops)} drop_worst=$worst '
      'drop_total=${drops.fold<int>(0, (a, b) => a + b)} '
      'dirty_windows=$dirty '
      'pace_off_median=${median(paces)}%',
    );
    // Flushed before exiting: `debugPrint` is asynchronous by default and
    // a bare `exit` here loses the very line the harness came for.
    Timer(const Duration(milliseconds: 300), () => exit(0));
  }

  /// Reads mpv properties, tolerating every way the read can fail.
  ///
  /// Properties are unavailable on the web backend, before
  /// initialisation, and individually whenever they do not apply to the
  /// current media (`decoder-frame-drop-count` on an audio-only file).
  /// None of that is worth losing a whole diagnostic line over.
  Future<Map<String, String>> _readProperties(List<String> names) async {
    final platform = _player.platform;
    if (platform is! NativePlayer) return const {};
    final result = <String, String>{};
    for (final name in names) {
      try {
        result[name] = await platform.getProperty(name);
      } catch (_) {
        // Left absent — the line prints `null` for it, which reads
        // correctly as "mpv would not say".
      }
    }
    return result;
  }

  Future<void> dispose() async {
    if (_timer != null) {
      SchedulerBinding.instance.removeTimingsCallback(_onFrameTimings);
    }
    _timer?.cancel();
    _timer = null;
    _probe?.stop();
    _probe = null;
    await _bufferingSub?.cancel();
    await _playingSub?.cancel();
  }
}

// Doublures autonomes de `lib/infrastructure/observability/`, absent des
// commits anciens. Comportement identique aux originaux.
const bool kPerfTrace = true;

class EventLoopProbe {
  EventLoopProbe({this.interval = const Duration(milliseconds: 16)});
  final Duration interval;
  Timer? _timer;
  final Stopwatch _clock = Stopwatch();
  int _lastTickMs = 0;
  int _maxLagMs = 0;
  int _stalls = 0;
  int _samples = 0;

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
      if (lag > _maxLagMs) _maxLagMs = lag;
      if (lag >= 100) _stalls++;
    });
  }

  Map<String, Object?> stop() {
    _timer?.cancel();
    _timer = null;
    _clock.stop();
    return {'max_lag_ms': _maxLagMs, 'stalls': _stalls, 'samples': _samples};
  }
}
