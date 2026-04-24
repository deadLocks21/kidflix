import 'package:flutter/widgets.dart';

/// Abstraction over the concrete video player library (`media_kit`).
///
/// Lives in the UI layer — this is not a Domain port. The only reason it
/// exists is to let widget tests drive the `PlayerPage` without
/// initialising the native media pipeline. Production code always uses
/// the `MediaKitPlayerEngine` via the default factory.
abstract class PlayerEngine {
  /// Opens [filePath] (a local file, passed as an absolute path without
  /// the `file://` scheme). When [initialPosition] is non-null the
  /// engine seeks to it before playback starts.
  Future<void> open(String filePath, {Duration initialPosition = Duration.zero});

  Future<void> play();

  Future<void> pause();

  Future<void> seek(Duration position);

  Future<void> dispose();

  /// Stream of the current playback position, updated frequently.
  Stream<Duration> get positionStream;

  /// Stream of the media duration. Emits `null` until the media is
  /// opened and its duration resolved.
  Stream<Duration?> get durationStream;

  /// Stream of the playing/paused state.
  Stream<bool> get playingStream;

  /// The widget rendering the video frames. Call after [open] has
  /// returned.
  Widget buildSurface();
}

/// Factory function creating a fresh [PlayerEngine]. Injected into
/// `PlayerPage` to allow test doubles.
typedef PlayerEngineFactory = PlayerEngine Function();
