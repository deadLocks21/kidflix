import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:kidflix/infrastructure/downloads/download_manifest_entry.dart';
import 'package:synchronized/synchronized.dart';

/// Namespace of a manifest entry. Movies and episodes correspond to
/// actually-downloaded files on disk ; series entries are pure metadata
/// snapshots that exist alongside their downloaded episodes so the
/// offline home can rebuild a `Series` card without a network call.
enum ManifestEntryKind {
  movie,
  episode,
  series;

  String get pathSegment => switch (this) {
    ManifestEntryKind.movie => 'movies',
    ManifestEntryKind.episode => 'episodes',
    ManifestEntryKind.series => 'series',
  };

  static ManifestEntryKind? fromPathSegment(String segment) =>
      switch (segment) {
        'movies' => ManifestEntryKind.movie,
        'episodes' => ManifestEntryKind.episode,
        'series' => ManifestEntryKind.series,
        _ => null,
      };
}

/// Composite key inside the manifest JSON: `"movies/<id>"`,
/// `"episodes/<id>"` or `"series/<id>"`. Encapsulating the format here
/// lets the rest of the code use `(mediaId, kind)` and never touch the
/// wire format.
String _keyFor({required String mediaId, required ManifestEntryKind kind}) =>
    '${kind.pathSegment}/$mediaId';

/// One inventory line returned by [DownloadManifestStore.listAll].
///
/// [isEpisode] is preserved as a derived getter so legacy callers
/// written against the previous two-kind API keep working unchanged.
/// New callers should switch on [kind].
class DownloadManifestRecord {
  final String mediaId;
  final ManifestEntryKind kind;
  final DownloadManifestEntry entry;

  const DownloadManifestRecord({
    required this.mediaId,
    required this.kind,
    required this.entry,
  });

  /// Legacy accessor — returns `true` only for [ManifestEntryKind.episode].
  bool get isEpisode => kind == ManifestEntryKind.episode;

  /// Convenience accessor for the series namespace.
  bool get isSeries => kind == ManifestEntryKind.series;
}

/// Sidecar metadata store backing the `kind` / `completedAt` /
/// `lastPlayedAt` / `triggeredByProfileId` fields of each downloaded
/// item. Persists at `<downloadsDir>/manifest.json` as a JSON object
/// keyed by `"movies/<id>"` / `"episodes/<id>"` / `"series/<id>"`.
///
/// Movies and episodes correspond to actual files on disk (their entries
/// are written / removed alongside the binary). Series entries are pure
/// metadata snapshots: they have no file on disk but are needed by the
/// offline-catalog reconstruction so a downloaded episode's parent
/// series card shows up on the offline home.
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

  Future<void> remove({required String mediaId, required bool isEpisode});

  /// Returns every record across all three namespaces (movies, episodes,
  /// series). Consumers should switch on [DownloadManifestRecord.kind]
  /// to handle each appropriately. Legacy callers reading
  /// [DownloadManifestRecord.isEpisode] still work — they just see
  /// `false` for both movies and series ; combine with [kind] when the
  /// distinction matters.
  Future<List<DownloadManifestRecord>> listAll();

  /// Returns the series snapshot for [seriesId], or `null` when none
  /// exists. Series entries are written by [upsertSeries] and never
  /// have an associated file on disk.
  Future<DownloadManifestEntry?> findForSeries(String seriesId);

  /// Upserts the series snapshot for [seriesId]. The full snapshot is
  /// captured at the moment a parent series modal opens or one of its
  /// episodes is downloaded, so the offline home can rebuild the series
  /// card and detail modal.
  Future<void> upsertSeries(String seriesId, DownloadManifestEntry entry);

  /// Removes the series snapshot for [seriesId]. Idempotent.
  Future<void> removeSeries(String seriesId);

  /// Removes every entry across all three namespaces (movies, episodes,
  /// series) and deletes the backing `manifest.json`. Resets the
  /// in-memory cache to empty so subsequent reads start from a clean
  /// slate (a deleted file alone would not suffice — the loaded cache
  /// would be re-persisted on the next write). Idempotent; best-effort
  /// on the file deletion.
  Future<void> clear();
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
    return cache[_keyFor(
      mediaId: mediaId,
      kind: isEpisode ? ManifestEntryKind.episode : ManifestEntryKind.movie,
    )];
  }

  @override
  Future<void> upsert({
    required String mediaId,
    required bool isEpisode,
    required DownloadManifestEntry entry,
  }) async {
    await _lock.synchronized(() async {
      final cache = await _ensureLoadedUnlocked();
      cache[_keyFor(
            mediaId: mediaId,
            kind: isEpisode
                ? ManifestEntryKind.episode
                : ManifestEntryKind.movie,
          )] =
          entry;
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
      final removed = cache.remove(
        _keyFor(
          mediaId: mediaId,
          kind: isEpisode ? ManifestEntryKind.episode : ManifestEntryKind.movie,
        ),
      );
      if (removed != null) {
        await _persistUnlocked(cache);
      }
    });
  }

  @override
  Future<List<DownloadManifestRecord>> listAll() async {
    final cache = await _ensureLoaded();
    final records = <DownloadManifestRecord>[];
    for (final e in cache.entries) {
      final parts = e.key.split('/');
      if (parts.length < 2) continue;
      final kind = ManifestEntryKind.fromPathSegment(parts.first);
      if (kind == null) continue;
      final mediaId = parts.skip(1).join('/');
      records.add(
        DownloadManifestRecord(mediaId: mediaId, kind: kind, entry: e.value),
      );
    }
    return List.unmodifiable(records);
  }

  @override
  Future<DownloadManifestEntry?> findForSeries(String seriesId) async {
    final cache = await _ensureLoaded();
    return cache[_keyFor(mediaId: seriesId, kind: ManifestEntryKind.series)];
  }

  @override
  Future<void> upsertSeries(
    String seriesId,
    DownloadManifestEntry entry,
  ) async {
    await _lock.synchronized(() async {
      final cache = await _ensureLoadedUnlocked();
      cache[_keyFor(mediaId: seriesId, kind: ManifestEntryKind.series)] = entry;
      await _persistUnlocked(cache);
    });
  }

  @override
  Future<void> removeSeries(String seriesId) async {
    await _lock.synchronized(() async {
      final cache = await _ensureLoadedUnlocked();
      final removed = cache.remove(
        _keyFor(mediaId: seriesId, kind: ManifestEntryKind.series),
      );
      if (removed != null) {
        await _persistUnlocked(cache);
      }
    });
  }

  @override
  Future<void> clear() async {
    await _lock.synchronized(() async {
      _cache = {};
      final dir = await _resolveDir();
      final file = File('${dir.path}/manifest.json');
      if (await file.exists()) {
        try {
          await file.delete();
        } catch (_) {
          // Best-effort: the empty in-memory cache already reflects the
          // cleared state, and the next write rewrites the file from it.
        }
      }
    });
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
          DownloadManifestEntry.fromJson((v as Map).cast<String, dynamic>()),
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
