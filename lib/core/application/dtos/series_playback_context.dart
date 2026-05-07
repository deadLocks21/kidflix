/// Playback mode for a series viewing session.
enum SeriesPlaybackMode { linear, shuffle }

/// Lightweight value object attached to an episode the player is about
/// to open, telling it "you are part of series X, in mode Y".
///
/// Lives in the Application layer because the PlayerPage UI consumes
/// it and the router constructs it from the URL — but it carries no
/// Riverpod and no IO. Out-of-band of the wire DTO surface (no
/// `fromWire` here): it is purely a UI-routing concern.
class SeriesPlaybackContext {
  final String seriesId;
  final SeriesPlaybackMode mode;

  const SeriesPlaybackContext({required this.seriesId, required this.mode});

  @override
  bool operator ==(Object other) =>
      other is SeriesPlaybackContext &&
      other.seriesId == seriesId &&
      other.mode == mode;

  @override
  int get hashCode => Object.hash(seriesId, mode);
}
