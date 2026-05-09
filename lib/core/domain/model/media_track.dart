/// A single audio or subtitle stream exposed by the underlying media file.
///
/// Carries only what the UI needs to render a selector: an opaque [id]
/// that the player engine understands, an optional human label, and an
/// optional ISO language code (already lowercased) used to match the
/// user's saved preference.
///
/// `MediaTrack` is plat and inert (no Flutter, no Riverpod, no engine
/// types) so it can travel from the engine layer through application
/// usecases without breaking the architectural rule that UI never sees
/// engine internals.
enum MediaTrackKind { audio, subtitle }

class MediaTrack {
  final String id;
  final MediaTrackKind kind;
  final String? title;
  final String? language;
  final bool isDefault;

  const MediaTrack({
    required this.id,
    required this.kind,
    this.title,
    this.language,
    this.isDefault = false,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MediaTrack && other.id == id && other.kind == kind);

  @override
  int get hashCode => Object.hash(id, kind);

  @override
  String toString() =>
      'MediaTrack(id: $id, kind: $kind, title: $title, language: $language)';
}
