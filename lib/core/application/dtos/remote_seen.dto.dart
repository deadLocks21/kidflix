import 'package:kidflix/core/domain/model/seen_mark.dart';

/// Parses a single wire entry of `GET /profiles/{p}/seen` into a Domain
/// [SeenMark].
///
/// The wire shape (cf. `SEEN_FEATURE.md`):
///
/// ```json
/// {
///   "kind": "movie",
///   "profile_id": "...",
///   "media_id": "...",
///   "marked_at": "2026-05-12T10:30:00Z"
/// }
/// ```
///
/// Non-`movie` kinds are not expected at MVP (series deferred) and raise
/// a [FormatException] so a future series rollout cannot silently drop
/// entries through this parser.
SeenMark seenMarkFromJson(Map<String, dynamic> json) {
  final kind = json['kind'];
  if (kind != 'movie') {
    throw FormatException('Unsupported seen kind: $kind');
  }
  return SeenMark(
    profileId: json['profile_id'] as String,
    movieId: json['media_id'] as String,
    markedAt: DateTime.parse(json['marked_at'] as String),
  );
}
