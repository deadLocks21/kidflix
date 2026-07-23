import 'package:kidflix/core/domain/model/media_track.dart';

/// Common ISO 639 codes (2- and 3-letter, both bibliographic and
/// terminological 3-letter variants) translated to user-facing French.
/// mpv typically reports 3-letter codes (e.g. `fre`, `eng`); covering
/// the 2-letter forms keeps us robust to backends that don't.
const Map<String, String> languageNames = {
  'fr': 'Français',
  'fre': 'Français',
  'fra': 'Français',
  'en': 'Anglais',
  'eng': 'Anglais',
  'es': 'Espagnol',
  'spa': 'Espagnol',
  'it': 'Italien',
  'ita': 'Italien',
  'de': 'Allemand',
  'ger': 'Allemand',
  'deu': 'Allemand',
  'pt': 'Portugais',
  'por': 'Portugais',
  'nl': 'Néerlandais',
  'dut': 'Néerlandais',
  'nld': 'Néerlandais',
  'ja': 'Japonais',
  'jpn': 'Japonais',
  'ko': 'Coréen',
  'kor': 'Coréen',
  'zh': 'Chinois',
  'chi': 'Chinois',
  'zho': 'Chinois',
  'ar': 'Arabe',
  'ara': 'Arabe',
  'ru': 'Russe',
  'rus': 'Russe',
};

/// Computes a unique, human-readable label per track, keyed by track id.
///
/// Two passes: first the natural label for each track (title, else a
/// French language name, else `Piste <id>`); then, for any label shared
/// by ≥ 2 tracks — typical of files carrying two French subtitle streams
/// — a `· #<id>` suffix disambiguates them.
///
/// Shared by the on-device track sheet and the remote-control state
/// snapshot so both name the same stream identically; a remote showing
/// "Français" for what the TV calls "Français · #3" would be its own
/// small bug.
Map<String, String> buildTrackLabels(List<MediaTrack> tracks) {
  final natural = <String, String>{
    for (final t in tracks) t.id: naturalTrackLabel(t),
  };
  final counts = <String, int>{};
  for (final label in natural.values) {
    counts[label] = (counts[label] ?? 0) + 1;
  }
  return {
    for (final t in tracks)
      t.id: counts[natural[t.id]]! > 1
          ? '${natural[t.id]} · #${t.id}'
          : natural[t.id]!,
  };
}

String naturalTrackLabel(MediaTrack track) {
  final title = track.title?.trim();
  if (title != null && title.isNotEmpty) return title;
  final lang = track.language;
  if (lang != null && lang.isNotEmpty) {
    return languageNames[lang] ?? lang.toUpperCase();
  }
  return 'Piste ${track.id}';
}
