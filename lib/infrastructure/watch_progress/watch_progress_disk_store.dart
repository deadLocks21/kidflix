import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:kidflix/core/domain/model/watch_progress.dart';
import 'package:synchronized/synchronized.dart';

/// Composite key inside the JSON store. Mirrors the manifest store
/// pattern: `"movies/<profileId>/<movieId>"` or
/// `"episodes/<profileId>/<episodeId>"`.
String _keyFor({
  required bool isEpisode,
  required String profileId,
  required String mediaId,
}) =>
    '${isEpisode ? 'episodes' : 'movies'}/$profileId/$mediaId';

/// Local mirror of every `WatchProgress` known to the client, kept in
/// the JSON sidecar `<appDocs>/watch_progress.json`.
///
/// Acts as the source of truth for *reads* on the offline-first path:
/// `OfflineFirstWatchProgressRepository` queries this store first and
/// only falls back to the remote in rare cases. Writes go through this
/// store before reaching the remote so the UI sees them instantly,
/// regardless of connectivity.
///
/// Dégradable: an absent or malformed file is treated as empty —
/// callers see "no progress" rather than a crash.
///
/// The store is process-private — there is no cross-app sharing — so
/// the in-memory cache is authoritative once loaded ; reload requires
/// re-instantiating the store (tests, after a wipe, …).
abstract interface class WatchProgressDiskStore {
  Future<WatchProgress?> find({
    required bool isEpisode,
    required String profileId,
    required String mediaId,
  });

  Future<void> save(WatchProgress progress);

  Future<void> setDismissed({
    required bool isEpisode,
    required String profileId,
    required String mediaId,
    required bool dismissed,
  });

  Future<List<WatchProgress>> listForProfile(String profileId);

  /// Bulk-replaces every entry for [profileId] with [progresses]. Used
  /// by the sync layer when it pulls the server-side state on a
  /// reconnect (server is the eventual source of truth).
  Future<void> replaceProfile(
    String profileId,
    List<WatchProgress> progresses,
  );
}

/// JSON-file backed implementation. Lazy-loads at first access,
/// serializes writes through a [Lock], and uses write-then-rename
/// atomicity for every persist.
class JsonFileWatchProgressStore implements WatchProgressDiskStore {
  /// Returns the directory where `watch_progress.json` lives. Typically
  /// `getApplicationDocumentsDirectory()`.
  final Future<Directory> Function() _resolveDir;

  final Lock _lock = Lock();
  Map<String, WatchProgress>? _cache;

  JsonFileWatchProgressStore({
    required Future<Directory> Function() resolveDir,
  }) : _resolveDir = resolveDir;

  @override
  Future<WatchProgress?> find({
    required bool isEpisode,
    required String profileId,
    required String mediaId,
  }) async {
    final cache = await _ensureLoaded();
    return cache[_keyFor(
      isEpisode: isEpisode,
      profileId: profileId,
      mediaId: mediaId,
    )];
  }

  @override
  Future<void> save(WatchProgress progress) async {
    await _lock.synchronized(() async {
      final cache = await _ensureLoadedUnlocked();
      switch (progress) {
        case MovieProgress(:final profileId, :final movieId):
          cache[_keyFor(
            isEpisode: false,
            profileId: profileId,
            mediaId: movieId,
          )] = progress;
        case EpisodeProgress(:final profileId, :final episodeId):
          cache[_keyFor(
            isEpisode: true,
            profileId: profileId,
            mediaId: episodeId,
          )] = progress;
      }
      await _persistUnlocked(cache);
    });
  }

  @override
  Future<void> setDismissed({
    required bool isEpisode,
    required String profileId,
    required String mediaId,
    required bool dismissed,
  }) async {
    await _lock.synchronized(() async {
      final cache = await _ensureLoadedUnlocked();
      final key = _keyFor(
        isEpisode: isEpisode,
        profileId: profileId,
        mediaId: mediaId,
      );
      final existing = cache[key];
      if (existing == null) return;
      cache[key] = _withDismissed(existing, dismissed);
      await _persistUnlocked(cache);
    });
  }

  @override
  Future<List<WatchProgress>> listForProfile(String profileId) async {
    final cache = await _ensureLoaded();
    return cache.values
        .where((p) => p.profileId == profileId)
        .toList(growable: false);
  }

  @override
  Future<void> replaceProfile(
    String profileId,
    List<WatchProgress> progresses,
  ) async {
    await _lock.synchronized(() async {
      final cache = await _ensureLoadedUnlocked();
      cache.removeWhere((_, p) => p.profileId == profileId);
      for (final p in progresses) {
        switch (p) {
          case MovieProgress(:final movieId):
            cache[_keyFor(
              isEpisode: false,
              profileId: profileId,
              mediaId: movieId,
            )] = p;
          case EpisodeProgress(:final episodeId):
            cache[_keyFor(
              isEpisode: true,
              profileId: profileId,
              mediaId: episodeId,
            )] = p;
        }
      }
      await _persistUnlocked(cache);
    });
  }

  // ── Internals ─────────────────────────────────────────────────────

  Future<Map<String, WatchProgress>> _ensureLoaded() async {
    if (_cache != null) return _cache!;
    return _lock.synchronized(_ensureLoadedUnlocked);
  }

  Future<Map<String, WatchProgress>> _ensureLoadedUnlocked() async {
    if (_cache != null) return _cache!;
    final dir = await _resolveDir();
    final file = File('${dir.path}/watch_progress.json');
    if (!await file.exists()) {
      _cache = {};
      return _cache!;
    }
    try {
      final raw = await file.readAsString();
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        developer.log(
          'watch_progress.json content is not a JSON object — treating as empty',
          name: 'kidflix.watch_progress.store',
          level: 900,
        );
        _cache = {};
        return _cache!;
      }
      _cache = {};
      for (final entry in decoded.entries) {
        final parsed = _parseEntry(entry.key, entry.value);
        if (parsed != null) _cache![entry.key] = parsed;
      }
      return _cache!;
    } catch (e) {
      developer.log(
        'watch_progress.json malformed — treating as empty',
        name: 'kidflix.watch_progress.store',
        level: 900,
        error: e,
      );
      _cache = {};
      return _cache!;
    }
  }

  Future<void> _persistUnlocked(Map<String, WatchProgress> cache) async {
    final dir = await _resolveDir();
    if (!await dir.exists()) await dir.create(recursive: true);
    final tmp = File('${dir.path}/watch_progress.json.tmp');
    final finalFile = File('${dir.path}/watch_progress.json');
    final payload = cache.map((k, v) => MapEntry(k, _entryToJson(v)));
    await tmp.writeAsString(jsonEncode(payload), flush: true);
    await tmp.rename(finalFile.path);
  }

  Map<String, dynamic> _entryToJson(WatchProgress p) => {
        'positionSeconds': p.positionSeconds,
        'completed': p.completed,
        'dismissed': p.dismissed,
        'updatedAt': p.updatedAt.toUtc().toIso8601String(),
      };

  WatchProgress? _parseEntry(String key, Object? raw) {
    if (raw is! Map) return null;
    final json = raw.cast<String, dynamic>();
    final parts = key.split('/');
    if (parts.length < 3) return null;
    final isEpisode = parts.first == 'episodes';
    final profileId = parts[1];
    final mediaId = parts.skip(2).join('/');
    final positionSeconds = (json['positionSeconds'] as num?)?.toInt();
    final completed = json['completed'] as bool?;
    if (positionSeconds == null || completed == null) return null;
    final dismissed = (json['dismissed'] as bool?) ?? false;
    final updatedAtRaw = json['updatedAt'];
    final updatedAt = updatedAtRaw is String
        ? (DateTime.tryParse(updatedAtRaw) ?? DateTime.now().toUtc())
        : DateTime.now().toUtc();
    if (isEpisode) {
      return EpisodeProgress(
        profileId: profileId,
        episodeId: mediaId,
        positionSeconds: positionSeconds,
        completed: completed,
        dismissed: dismissed,
        updatedAt: updatedAt,
      );
    }
    return MovieProgress(
      profileId: profileId,
      movieId: mediaId,
      positionSeconds: positionSeconds,
      completed: completed,
      dismissed: dismissed,
      updatedAt: updatedAt,
    );
  }

  WatchProgress _withDismissed(WatchProgress p, bool dismissed) {
    return switch (p) {
      MovieProgress() => MovieProgress(
          profileId: p.profileId,
          movieId: p.movieId,
          positionSeconds: p.positionSeconds,
          completed: p.completed,
          dismissed: dismissed,
          updatedAt: p.updatedAt,
        ),
      EpisodeProgress() => EpisodeProgress(
          profileId: p.profileId,
          episodeId: p.episodeId,
          positionSeconds: p.positionSeconds,
          completed: p.completed,
          dismissed: dismissed,
          updatedAt: p.updatedAt,
        ),
    };
  }
}
