import 'package:flutter/widgets.dart';
import 'package:kidflix/core/domain/model/media_track.dart';

/// Snapshot of the audio + subtitle tracks currently advertised by the
/// engine for the open media. Excludes the synthetic `auto`/`no`
/// entries — those are exposed only via [PlayerEngine.setAudioTrack] and
/// [PlayerEngine.setSubtitleTrack] using the special ids `'auto'` and
/// `'no'`.
typedef AvailableTracks = ({List<MediaTrack> audio, List<MediaTrack> subtitle});

/// Snapshot of the engine's currently selected audio and subtitle track
/// ids. The ids match either an entry in [AvailableTracks] or one of
/// the synthetic values `'auto'` / `'no'`.
typedef SelectedTracks = ({String audioId, String subtitleId});

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
  Future<void> open(
    String filePath, {
    Duration initialPosition = Duration.zero,
  });

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

  /// Stream of the output volume on a 0..100 scale.
  Stream<double> get volumeStream;

  /// Sets the output volume. [volume] is clamped to 0..100 by the
  /// implementation.
  Future<void> setVolume(double volume);

  /// Stream of the audio + subtitle track lists currently advertised by
  /// the engine. Emits a fresh snapshot whenever the underlying media
  /// changes.
  Stream<AvailableTracks> get tracksStream;

  /// Stream of the engine's currently selected track ids. Emits when the
  /// engine itself picks a default after open and after every
  /// [setAudioTrack] / [setSubtitleTrack] call.
  Stream<SelectedTracks> get selectedTracksStream;

  /// Switches the active audio track. [id] must be either an id from
  /// the latest [tracksStream] snapshot, or one of `'auto'` / `'no'`.
  Future<void> setAudioTrack(String id);

  /// Switches the active subtitle track. [id] accepts the same values
  /// as [setAudioTrack]; pass `'no'` to disable subtitles.
  Future<void> setSubtitleTrack(String id);

  /// The widget rendering the video frames. Call after [open] has
  /// returned.
  Widget buildSurface();
}

/// Factory function creating a fresh [PlayerEngine]. Injected into
/// `PlayerPage` to allow test doubles.
typedef PlayerEngineFactory = PlayerEngine Function();
