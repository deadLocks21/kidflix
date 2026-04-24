/// Pure normalization helper used by the `search` capability.
///
/// Applies, in order: trim, lowercase, then a diacritic-folding pass that
/// maps common Latin accented characters to their unaccented forms. The
/// fold table targets French first, with coverage for Spanish and
/// Portuguese diacritics also present on real movie catalogs.
///
/// Both the query and the searched field SHALL go through this function
/// before comparison so that "astérix" matches "Asterix" and vice versa.
library;

/// Lowercase-only fold table. [String.toLowerCase] is applied first, so
/// uppercase accented characters (À, É, ...) become their lowercase
/// accented counterparts (à, é, ...) before lookup.
const Map<int, int> _lowerDiacriticFolds = {
  0x00E0: 0x0061, // à → a
  0x00E1: 0x0061, // á → a
  0x00E2: 0x0061, // â → a
  0x00E3: 0x0061, // ã → a
  0x00E4: 0x0061, // ä → a
  0x00E5: 0x0061, // å → a
  0x00E7: 0x0063, // ç → c
  0x00E8: 0x0065, // è → e
  0x00E9: 0x0065, // é → e
  0x00EA: 0x0065, // ê → e
  0x00EB: 0x0065, // ë → e
  0x00EC: 0x0069, // ì → i
  0x00ED: 0x0069, // í → i
  0x00EE: 0x0069, // î → i
  0x00EF: 0x0069, // ï → i
  0x00F1: 0x006E, // ñ → n
  0x00F2: 0x006F, // ò → o
  0x00F3: 0x006F, // ó → o
  0x00F4: 0x006F, // ô → o
  0x00F5: 0x006F, // õ → o
  0x00F6: 0x006F, // ö → o
  0x00F9: 0x0075, // ù → u
  0x00FA: 0x0075, // ú → u
  0x00FB: 0x0075, // û → u
  0x00FC: 0x0075, // ü → u
  0x00FD: 0x0079, // ý → y
  0x00FF: 0x0079, // ÿ → y
};

/// Normalizes [input] for case- and accent-insensitive matching.
///
/// Steps:
///   1. Trim leading/trailing whitespace.
///   2. Lowercase via [String.toLowerCase].
///   3. Fold Latin diacritics per [_lowerDiacriticFolds].
///
/// Characters outside the fold table pass through unchanged (digits,
/// punctuation, unmapped scripts).
String normalizeForSearch(String input) {
  final trimmed = input.trim();
  if (trimmed.isEmpty) return '';
  final lowered = trimmed.toLowerCase();
  final buffer = StringBuffer();
  for (final rune in lowered.runes) {
    buffer.writeCharCode(_lowerDiacriticFolds[rune] ?? rune);
  }
  return buffer.toString();
}
