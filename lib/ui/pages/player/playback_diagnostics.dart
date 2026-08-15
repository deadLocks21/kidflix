import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:kidflix/infrastructure/observability/event_loop_probe.dart';
import 'package:kidflix/infrastructure/observability/perf_trace.dart';
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
      'build_ms=$maxBuildMs raster_ms=$maxRasterMs '
      'stalls=${jank['stalls']} '
      'avsync=${props['avsync']} '
      'cache=${props['cache-buffering-state']}%',
    );
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
