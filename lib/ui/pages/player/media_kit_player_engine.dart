import 'package:flutter/widgets.dart';
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
    _player = Player();
    _controller = VideoController(_player);
    // Use MaterialVideoControls (default via AdaptiveVideoControls).
    // The PlayerPage wraps the surface with a MaterialVideoControlsTheme
    // providing its custom top/bottom button bars and tuning.
    _surface = Video(controller: _controller);
  }

  @override
  Future<void> open(
    String filePath, {
    Duration initialPosition = Duration.zero,
  }) async {
    await _player.open(Media('file://$filePath'), play: false);
    if (initialPosition > Duration.zero) {
      await _player.seek(initialPosition);
    }
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> dispose() async {
    await _player.dispose();
  }

  @override
  Stream<Duration> get positionStream => _player.stream.position;

  @override
  Stream<Duration?> get durationStream => _player.stream.duration;

  @override
  Stream<bool> get playingStream => _player.stream.playing;

  @override
  Widget buildSurface() => _surface;
}

PlayerEngine defaultPlayerEngineFactory() => MediaKitPlayerEngine();
