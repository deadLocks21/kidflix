/// Formats a [Duration] for display using French conventions.
///
/// Rules:
/// - `< 60 min` → `"X min"` (e.g. `"42 min"`, `"0 min"` when zero)
/// - `>= 60 min` → `"XhYY"` with zero-padded minutes and no whitespace
///   between the hour and minutes (e.g. `"1h52"`, `"1h00"`, `"2h05"`).
String formatDurationHuman(Duration d) {
  final totalMinutes = d.inMinutes;
  if (totalMinutes < 60) {
    return '$totalMinutes min';
  }
  final hours = totalMinutes ~/ 60;
  final minutes = totalMinutes % 60;
  return '${hours}h${minutes.toString().padLeft(2, '0')}';
}

/// Formats a [Duration] as a playback timecode: `m:ss` under an hour,
/// `h:mm:ss` at or above one.
///
/// Distinct from [formatDurationHuman], which describes a *length* ("1h52")
/// — this one labels a *position on a timeline*, where seconds matter and
/// the fields must stay aligned as they tick.
///
/// Negative durations clamp to zero: a seek bar dragged to the far left
/// while the position stream lags can briefly compute a negative value,
/// and "-0:03" is never something to show.
String formatTimecode(Duration d) {
  final total = d.isNegative ? 0 : d.inSeconds;
  final hours = total ~/ 3600;
  final minutes = (total % 3600) ~/ 60;
  final seconds = total % 60;
  final paddedSeconds = seconds.toString().padLeft(2, '0');
  if (hours == 0) return '$minutes:$paddedSeconds';
  return '$hours:${minutes.toString().padLeft(2, '0')}:$paddedSeconds';
}
