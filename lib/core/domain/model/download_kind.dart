/// Discriminator between an implicit cache download and an explicit
/// "Télécharger" download.
///
/// * [cache] is the default value for any download whose origin is the
///   implicit playback flow — the player started it transparently. These
///   files are subject to auto-deletion by `DownloadCleanupService` after
///   a configurable inactivity window (`lastPlayedAt + 30 days` by default).
/// * [download] is set only by an explicit `MarkAsDownloadUseCase`
///   invocation — typically following a `[Télécharger]` button press
///   (gated by the parent PIN when triggered from a kid profile). These
///   files are kept until manual deletion.
enum DownloadKind {
  cache,
  download;

  /// Lower-case canonical string representation, matching the manifest
  /// JSON schema (`"cache"` or `"download"`).
  String get jsonValue => name;

  /// Parses [raw] back into a [DownloadKind]. Tolerant: any unknown or
  /// `null` value resolves to [cache] — the safe default that does not
  /// over-promote a file the parent never explicitly kept.
  static DownloadKind fromJson(String? raw) {
    return switch (raw) {
      'download' => DownloadKind.download,
      'cache' => DownloadKind.cache,
      _ => DownloadKind.cache,
    };
  }
}
