import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:kidflix/core/domain/model/media_track.dart';
import 'package:kidflix/shared/video_controller_config.dart';
import 'package:kidflix/ui/pages/player/player_engine.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

/// Production [PlayerEngine] wrapping `media_kit`.
///
/// The [Video] widget is constructed once and cached so that successive
/// [buildSurface] calls return the same instance — this avoids duplicate
/// GlobalKey registrations when the parent rebuilds (e.g., when controls
/// overlay toggles on/off).
class MediaKitPlayerEngine implements PlayerEngine {
  late final Player _player;
  late final VideoController _controller;
  late final Widget _surface;

  MediaKitPlayerEngine() {
    // [MPVLogLevel.warn] surfaces demux / decoder problems through
    // [Player.stream.log] without flooding the console — the default
    // [MPVLogLevel.none] silently drops everything, leaving us blind on
    // pre-roll stalls.
    _player = Player(
      configuration: const PlayerConfiguration(logLevel: MPVLogLevel.warn),
    );
    _controller = VideoController(
      _player,
      configuration: videoControllerConfiguration(),
    );
    // Use MaterialVideoControls (default via AdaptiveVideoControls).
    // The PlayerPage wraps the surface with a MaterialVideoControlsTheme
    // providing its custom top/bottom button bars and tuning.
    _surface = Video(controller: _controller);
    // Diagnostic: surface mpv error and log streams to the console so
    // playback failures (codec unsupported, demux errors…) are visible
    // in `flutter run` output.
    _errorSub = _player.stream.error.listen(
      (e) => debugPrint('[kidflix.player] mpv error: $e'),
    );
    _logSub = _player.stream.log.listen(
      (l) => debugPrint('[kidflix.player] [${l.level}] ${l.prefix}: ${l.text}'),
    );
  }

  StreamSubscription<String>? _errorSub;
  StreamSubscription<PlayerLog>? _logSub;

  @override
  Future<void> open(
    String filePath, {
    Duration initialPosition = Duration.zero,
  }) async {
    // Pass the resume position via `Media.start` rather than calling
    // `_player.seek(...)` after `open()`. mpv applies `--start=N` as
    // part of the open lifecycle; a post-open seek can be silently
    // dropped on iOS if the demuxer hasn't finished initialising.
    await _player.open(
      Media(
        'file://$filePath',
        start: initialPosition > Duration.zero ? initialPosition : null,
      ),
      play: false,
    );
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> dispose() async {
    await _errorSub?.cancel();
    await _logSub?.cancel();
    await _player.dispose();
  }

  @override
  Stream<Duration> get positionStream => _player.stream.position;

  @override
  Stream<Duration?> get durationStream => _player.stream.duration;

  @override
  Stream<bool> get playingStream => _player.stream.playing;

  @override
  Stream<double> get volumeStream async* {
    // Seeded like the track streams: mpv sets the initial volume during
    // player construction, before anything can subscribe.
    yield _player.state.volume;
    yield* _player.stream.volume;
  }

  @override
  Future<void> setVolume(double volume) =>
      _player.setVolume(volume.clamp(0, 100));

  @override
  Stream<AvailableTracks> get tracksStream async* {
    // Seed with the engine's current snapshot so the subscriber sees
    // tracks already discovered by mpv before our `listen()` call. The
    // broadcast stream behind `_player.stream.tracks` does not replay
    // its last value to late subscribers — when the demuxer parses the
    // track list synchronously during `open()`, the event can fire
    // before our listener is even attached. The seed makes the flow
    // robust regardless of subscription timing.
    yield _mapTracks(_player.state.tracks);
    yield* _player.stream.tracks.map(_mapTracks);
  }

  @override
  Stream<SelectedTracks> get selectedTracksStream async* {
    final initial = _player.state.track;
    yield (audioId: initial.audio.id, subtitleId: initial.subtitle.id);
    yield* _player.stream.track.map(
      (t) => (audioId: t.audio.id, subtitleId: t.subtitle.id),
    );
  }

  @override
  Future<void> setAudioTrack(String id) {
    return _player.setAudioTrack(_audioTrackForId(id));
  }

  @override
  Future<void> setSubtitleTrack(String id) {
    return _player.setSubtitleTrack(_subtitleTrackForId(id));
  }

  @override
  Widget buildSurface() => _surface;

  AvailableTracks _mapTracks(Tracks tracks) {
    return (
      audio: [
        for (final t in tracks.audio)
          if (!_isSynthetic(t.id))
            MediaTrack(
              id: t.id,
              kind: MediaTrackKind.audio,
              title: t.title,
              language: _normalizeLanguage(t.language),
            ),
      ],
      subtitle: [
        for (final t in tracks.subtitle)
          if (!_isSynthetic(t.id))
            MediaTrack(
              id: t.id,
              kind: MediaTrackKind.subtitle,
              title: t.title,
              language: _normalizeLanguage(t.language),
            ),
      ],
    );
  }

  bool _isSynthetic(String id) => id == 'auto' || id == 'no';

  String? _normalizeLanguage(String? language) {
    if (language == null) return null;
    final trimmed = language.trim();
    if (trimmed.isEmpty) return null;
    return trimmed.toLowerCase();
  }

  AudioTrack _audioTrackForId(String id) {
    if (id == 'auto') return AudioTrack.auto();
    if (id == 'no') return AudioTrack.no();
    return AudioTrack(id, null, null);
  }

  SubtitleTrack _subtitleTrackForId(String id) {
    if (id == 'auto') return SubtitleTrack.auto();
    if (id == 'no') return SubtitleTrack.no();
    return SubtitleTrack(id, null, null);
  }
}

PlayerEngine defaultPlayerEngineFactory() => MediaKitPlayerEngine();
