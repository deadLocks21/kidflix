import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:kidflix/infrastructure/downloads/download_manifest_entry.dart';
import 'package:synchronized/synchronized.dart';

/// Composite key inside the manifest JSON: `"movies/<id>"` /
/// `"episodes/<id>"`. Encapsulating the format here lets the rest of
/// the code use `(mediaId, isEpisode)` and never touch the wire format.
String _keyFor({required String mediaId, required bool isEpisode}) =>
    '${isEpisode ? 'episodes' : 'movies'}/$mediaId';

/// One inventory line returned by [DownloadManifestStore.listAll].
class DownloadManifestRecord {
  final String mediaId;
  final bool isEpisode;
  final DownloadManifestEntry entry;

  const DownloadManifestRecord({
    required this.mediaId,
    required this.isEpisode,
    required this.entry,
  });
}

/// Sidecar metadata store backing the `kind` / `completedAt` /
/// `lastPlayedAt` / `triggeredByProfileId` fields of each downloaded
/// item. Persists at `<downloadsDir>/manifest.json` as a JSON object
/// keyed by `"movies/<id>"` / `"episodes/<id>"`.
///
/// Dégradable: an absent or malformed manifest is treated as empty —
/// callers of [findFor] receive `null` and can fall back to default
/// `cache` semantics.
abstract interface class DownloadManifestStore {
  Future<DownloadManifestEntry?> findFor({
    required String mediaId,
    required bool isEpisode,
  });

  Future<void> upsert({
    required String mediaId,
    required bool isEpisode,
    required DownloadManifestEntry entry,
  });

  Future<void> remove({
    required String mediaId,
    required bool isEpisode,
  });

  Future<List<DownloadManifestRecord>> listAll();
}

/// JSON-file backed implementation. Lazy-loads the manifest into memory
/// at first access, serializes all writes through a [Lock], and uses
/// write-then-rename atomicity for every persist (ensures a crash
/// mid-write cannot leave a corrupted `manifest.json` on disk).
class JsonFileDownloadManifestStore implements DownloadManifestStore {
  /// Directory where `manifest.json` lives. Typically
  /// `${applicationDocumentsDirectory}/downloads/`.
  final Future<Directory> Function() _resolveDir;

  final Lock _lock = Lock();
  Map<String, DownloadManifestEntry>? _cache;

  JsonFileDownloadManifestStore({
    required Future<Directory> Function() resolveDownloadsDir,
  }) : _resolveDir = resolveDownloadsDir;

  @override
  Future<DownloadManifestEntry?> findFor({
    required String mediaId,
    required bool isEpisode,
  }) async {
    final cache = await _ensureLoaded();
    return cache[_keyFor(mediaId: mediaId, isEpisode: isEpisode)];
  }

  @override
  Future<void> upsert({
    required String mediaId,
    required bool isEpisode,
    required DownloadManifestEntry entry,
  }) async {
    await _lock.synchronized(() async {
      final cache = await _ensureLoadedUnlocked();
      cache[_keyFor(mediaId: mediaId, isEpisode: isEpisode)] = entry;
      await _persistUnlocked(cache);
    });
  }

  @override
  Future<void> remove({
    required String mediaId,
    required bool isEpisode,
  }) async {
    await _lock.synchronized(() async {
      final cache = await _ensureLoadedUnlocked();
      final removed =
          cache.remove(_keyFor(mediaId: mediaId, isEpisode: isEpisode));
      if (removed != null) {
        await _persistUnlocked(cache);
      }
    });
  }

  @override
  Future<List<DownloadManifestRecord>> listAll() async {
    final cache = await _ensureLoaded();
    return cache.entries.map((e) {
      final parts = e.key.split('/');
      final isEpisode = parts.first == 'episodes';
      final mediaId = parts.skip(1).join('/');
      return DownloadManifestRecord(
        mediaId: mediaId,
        isEpisode: isEpisode,
        entry: e.value,
      );
    }).toList(growable: false);
  }

  // ── Internals ─────────────────────────────────────────────────────

  Future<Map<String, DownloadManifestEntry>> _ensureLoaded() async {
    if (_cache != null) return _cache!;
    return _lock.synchronized(_ensureLoadedUnlocked);
  }

  Future<Map<String, DownloadManifestEntry>> _ensureLoadedUnlocked() async {
    if (_cache != null) return _cache!;
    final dir = await _resolveDir();
    final file = File('${dir.path}/manifest.json');
    if (!await file.exists()) {
      _cache = {};
      return _cache!;
    }
    try {
      final raw = await file.readAsString();
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        developer.log(
          'manifest.json content is not a JSON object — treating as empty',
          name: 'kidflix.downloads.manifest',
          level: 900, // WARNING
        );
        _cache = {};
        return _cache!;
      }
      _cache = decoded.map((k, v) {
        return MapEntry(
          k,
          DownloadManifestEntry.fromJson(
            (v as Map).cast<String, dynamic>(),
          ),
        );
      });
      return _cache!;
    } catch (e) {
      developer.log(
        'manifest.json malformed — treating as empty (parse error)',
        name: 'kidflix.downloads.manifest',
        level: 900, // WARNING
        error: e,
      );
      _cache = {};
      return _cache!;
    }
  }

  Future<void> _persistUnlocked(
    Map<String, DownloadManifestEntry> cache,
  ) async {
    final dir = await _resolveDir();
    if (!await dir.exists()) await dir.create(recursive: true);
    final tmp = File('${dir.path}/manifest.json.tmp');
    final finalFile = File('${dir.path}/manifest.json');
    final payload = cache.map((k, v) => MapEntry(k, v.toJson()));
    await tmp.writeAsString(jsonEncode(payload), flush: true);
    await tmp.rename(finalFile.path);
  }
}
