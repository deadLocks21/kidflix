/// The set of actions a mounted player exposes to remote devices.
///
/// Implemented by the player page and handed to the remote-playback host
/// while the page is alive. This is the seam that keeps the control
/// server ignorant of Flutter: the server receives a command, resolves it
/// against whatever is registered here, and never touches a widget.
///
/// Every method is best-effort and must not throw — a command arriving
/// mid-teardown is normal, not exceptional.
abstract class PlaybackRemoteControls {
  Future<void> play();

  Future<void> pause();

  Future<void> togglePlay();

  /// Absolute seek. Implementations still apply their own clamping (the
  /// not-yet-downloaded region stays out of reach).
  Future<void> seek(Duration position);

  Future<void> seekRelative(Duration delta);

  /// [trackId] is an engine track id, or `auto`.
  Future<void> setAudioTrack(String trackId);

  /// [trackId] is an engine track id, or `no` to switch subtitles off.
  Future<void> setSubtitleTrack(String trackId);

  /// [volume] on the engine's 0..100 scale.
  Future<void> setVolume(double volume);

  /// Leaves the player and returns to the catalogue.
  Future<void> stop();

  /// Restarts a download that failed, or re-runs a bootstrap that threw.
  /// No-op when nothing went wrong.
  Future<void> retryDownload();

  /// No-ops when the player has no series context or is at an edge.
  Future<void> nextEpisode();

  Future<void> previousEpisode();
}
