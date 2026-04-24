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
