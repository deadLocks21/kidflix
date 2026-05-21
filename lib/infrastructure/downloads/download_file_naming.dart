/// Single source of truth for the on-disk naming of downloaded media.
///
/// A completed download is `<mediaId>.<ext>`; an in-flight one is
/// `<mediaId>.<ext>.partial`. [ext] is derived from the download response
/// `Content-Type` ([extensionForContentType]) so an MKV
/// (`video/x-matroska`) source keeps its real container on disk instead
/// of being mislabelled `.mp4`.
///
/// Every lookup globs `<mediaId>.*` rather than assuming a fixed
/// extension, which keeps files written before this convention existed
/// (all named `.mp4`) discoverable with no migration.
///
/// **Invariant:** any extension [extensionForContentType] can return MUST
/// also be a member of [videoExtensions] — otherwise a freshly downloaded
/// file would be invisible to [parseMediaFileName] and the inventory scan.
library;

import 'dart:io';

/// Fallback extension when the response carries no usable `Content-Type`.
/// mpv content-probes regardless, so the extension is for inventory
/// honesty, not playback correctness.
const String defaultMediaExtension = 'mp4';

/// Recognized video container extensions (no leading dot). Used to tell a
/// media artifact apart from sidecars (e.g. `manifest.json`) when scanning
/// a directory. Must contain [defaultMediaExtension].
const Set<String> videoExtensions = {'mp4', 'mkv', 'webm'};

const String _partialSuffix = '.partial';

/// Maps a download response `Content-Type` to a bare file extension.
/// Strips any `; charset=…` / `; codecs=…` parameter and is
/// case-insensitive. Unknown or absent types fall back to
/// [defaultMediaExtension].
String extensionForContentType(String? contentType) {
  if (contentType == null) return defaultMediaExtension;
  final mime = contentType.split(';').first.trim().toLowerCase();
  return switch (mime) {
    'video/x-matroska' ||
    'video/matroska' ||
    'application/x-matroska' =>
      'mkv',
    'video/webm' => 'webm',
    'video/mp4' => 'mp4',
    _ => defaultMediaExtension,
  };
}

/// Bare file name of a completed download.
String mediaFileName(String mediaId, String ext) => '$mediaId.$ext';

/// Bare file name of an in-flight (partial) download.
String partialFileName(String mediaId, String ext) =>
    '$mediaId.$ext$_partialSuffix';

/// Parsed identity of an on-disk media file.
typedef MediaFileIdentity = ({String mediaId, String ext, bool isPartial});

/// Decodes a bare file name into `(mediaId, ext, isPartial)`, or `null`
/// when [fileName] is not a recognized media artifact.
///
/// A media id may itself contain dots, so the suffixes are stripped from
/// the right (`.partial` first, then the extension) rather than splitting
/// on the first dot.
MediaFileIdentity? parseMediaFileName(String fileName) {
  var name = fileName;
  final isPartial = name.endsWith(_partialSuffix);
  if (isPartial) {
    name = name.substring(0, name.length - _partialSuffix.length);
  }
  final dot = name.lastIndexOf('.');
  if (dot <= 0 || dot == name.length - 1) return null;
  final ext = name.substring(dot + 1).toLowerCase();
  if (!videoExtensions.contains(ext)) return null;
  return (mediaId: name.substring(0, dot), ext: ext, isPartial: isPartial);
}

/// Finds the completed file `<mediaId>.<ext>` (any known extension) in
/// [dir], or `null` when none exists.
Future<File?> findCompletedMediaFile(Directory dir, String mediaId) =>
    _firstMatch(dir, mediaId, partial: false);

/// Finds the in-flight `<mediaId>.<ext>.partial` file in [dir], or `null`.
Future<File?> findPartialMediaFile(Directory dir, String mediaId) =>
    _firstMatch(dir, mediaId, partial: true);

Future<File?> _firstMatch(
  Directory dir,
  String mediaId, {
  required bool partial,
}) async {
  if (!await dir.exists()) return null;
  await for (final entity in dir.list(followLinks: false)) {
    if (entity is! File) continue;
    final id = parseMediaFileName(entity.uri.pathSegments.last);
    if (id != null && id.mediaId == mediaId && id.isPartial == partial) {
      return entity;
    }
  }
  return null;
}

/// Deletes every on-disk artifact for [mediaId] (the completed file and
/// any `.partial`), regardless of extension. Idempotent; best-effort on
/// per-file errors.
Future<void> deleteMediaArtifacts(Directory dir, String mediaId) async {
  if (!await dir.exists()) return;
  await for (final entity in dir.list(followLinks: false)) {
    if (entity is! File) continue;
    final id = parseMediaFileName(entity.uri.pathSegments.last);
    if (id == null || id.mediaId != mediaId) continue;
    try {
      await entity.delete();
    } catch (_) {
      // Best-effort.
    }
  }
}
