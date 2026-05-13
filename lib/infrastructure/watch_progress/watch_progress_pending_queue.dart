import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:kidflix/core/domain/model/watch_progress.dart';
import 'package:synchronized/synchronized.dart';

/// Operation kind in the offline write queue. `save` covers position
/// updates and completion flips (the payload carries the full
/// progress) ; `dismiss` and `undismiss` carry only the key.
enum PendingProgressOpKind { save, dismiss, undismiss }

/// One pending write to be replayed against the remote backend once
/// connectivity returns. The triplet `(kind, isEpisode, profileId,
/// mediaId)` defines a stable key — newer operations for the same key
/// supersede older ones (last-write-wins) when the queue is drained.
class PendingProgressOp {
  final PendingProgressOpKind kind;
  final bool isEpisode;
  final String profileId;
  final String mediaId;
  final WatchProgress? progress;

  const PendingProgressOp({
    required this.kind,
    required this.isEpisode,
    required this.profileId,
    required this.mediaId,
    this.progress,
  });

  String get key =>
      '${isEpisode ? 'episodes' : 'movies'}/$profileId/$mediaId';

  Map<String, dynamic> toJson() => {
        'op': kind.name,
        'isEpisode': isEpisode,
        'profileId': profileId,
        'mediaId': mediaId,
        if (progress != null) ...{
          'positionSeconds': progress!.positionSeconds,
          'completed': progress!.completed,
          'updatedAt': progress!.updatedAt.toUtc().toIso8601String(),
        },
      };

  static PendingProgressOp? fromJson(Map<String, dynamic> json) {
    final opName = json['op'];
    final kind = PendingProgressOpKind.values
        .where((k) => k.name == opName)
        .cast<PendingProgressOpKind?>()
        .firstWhere((_) => true, orElse: () => null);
    if (kind == null) return null;
    final isEpisode = json['isEpisode'] as bool?;
    final profileId = json['profileId'] as String?;
    final mediaId = json['mediaId'] as String?;
    if (isEpisode == null || profileId == null || mediaId == null) {
      return null;
    }
    WatchProgress? progress;
    if (kind == PendingProgressOpKind.save) {
      final positionSeconds = (json['positionSeconds'] as num?)?.toInt();
      final completed = json['completed'] as bool?;
      final updatedAtRaw = json['updatedAt'];
      if (positionSeconds == null || completed == null) return null;
      final updatedAt = updatedAtRaw is String
          ? (DateTime.tryParse(updatedAtRaw) ?? DateTime.now().toUtc())
          : DateTime.now().toUtc();
      progress = isEpisode
          ? EpisodeProgress(
              profileId: profileId,
              episodeId: mediaId,
              positionSeconds: positionSeconds,
              completed: completed,
              updatedAt: updatedAt,
            )
          : MovieProgress(
              profileId: profileId,
              movieId: mediaId,
              positionSeconds: positionSeconds,
              completed: completed,
              updatedAt: updatedAt,
            );
    }
    return PendingProgressOp(
      kind: kind,
      isEpisode: isEpisode,
      profileId: profileId,
      mediaId: mediaId,
      progress: progress,
    );
  }
}

/// Persistent FIFO queue of pending watch-progress writes. Used by the
/// offline-first repository to buffer mutations made while the device
/// has no connectivity, drained by `WatchProgressSyncService` once
/// connectivity returns.
abstract interface class WatchProgressPendingQueue {
  /// Appends [op] to the queue. If a previous entry for the same key
  /// AND same op kind exists, it is replaced (last-write-wins). Save
  /// vs dismiss vs undismiss are stored separately — they target
  /// different endpoints and must all replay.
  Future<void> enqueue(PendingProgressOp op);

  /// Reads every pending operation in insertion order.
  Future<List<PendingProgressOp>> readAll();

  /// Removes [op] from the queue. Used by the sync service after a
  /// successful replay. Idempotent.
  Future<void> remove(PendingProgressOp op);

  /// Wipes the queue. Test helper.
  Future<void> clear();
}

/// JSON-array file-backed implementation, stored at
/// `<appDocs>/watch_progress_queue.json`.
class JsonFileWatchProgressPendingQueue implements WatchProgressPendingQueue {
  final Future<Directory> Function() _resolveDir;
  final Lock _lock = Lock();
  List<PendingProgressOp>? _cache;

  JsonFileWatchProgressPendingQueue({
    required Future<Directory> Function() resolveDir,
  }) : _resolveDir = resolveDir;

  @override
  Future<void> enqueue(PendingProgressOp op) async {
    await _lock.synchronized(() async {
      final cache = await _ensureLoadedUnlocked();
      cache.removeWhere((existing) =>
          existing.key == op.key && existing.kind == op.kind);
      cache.add(op);
      await _persistUnlocked(cache);
    });
  }

  @override
  Future<List<PendingProgressOp>> readAll() async {
    final cache = await _ensureLoaded();
    return List.unmodifiable(cache);
  }

  @override
  Future<void> remove(PendingProgressOp op) async {
    await _lock.synchronized(() async {
      final cache = await _ensureLoadedUnlocked();
      cache.removeWhere((existing) =>
          existing.key == op.key && existing.kind == op.kind);
      await _persistUnlocked(cache);
    });
  }

  @override
  Future<void> clear() async {
    await _lock.synchronized(() async {
      _cache = [];
      await _persistUnlocked(_cache!);
    });
  }

  Future<List<PendingProgressOp>> _ensureLoaded() async {
    if (_cache != null) return _cache!;
    return _lock.synchronized(_ensureLoadedUnlocked);
  }

  Future<List<PendingProgressOp>> _ensureLoadedUnlocked() async {
    if (_cache != null) return _cache!;
    final dir = await _resolveDir();
    final file = File('${dir.path}/watch_progress_queue.json');
    if (!await file.exists()) {
      _cache = [];
      return _cache!;
    }
    try {
      final raw = await file.readAsString();
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        developer.log(
          'watch_progress_queue.json content is not a JSON array — treating as empty',
          name: 'kidflix.watch_progress.queue',
          level: 900,
        );
        _cache = [];
        return _cache!;
      }
      _cache = [];
      for (final item in decoded) {
        if (item is Map) {
          final parsed =
              PendingProgressOp.fromJson(item.cast<String, dynamic>());
          if (parsed != null) _cache!.add(parsed);
        }
      }
      return _cache!;
    } catch (e) {
      developer.log(
        'watch_progress_queue.json malformed — treating as empty',
        name: 'kidflix.watch_progress.queue',
        level: 900,
        error: e,
      );
      _cache = [];
      return _cache!;
    }
  }

  Future<void> _persistUnlocked(List<PendingProgressOp> cache) async {
    final dir = await _resolveDir();
    if (!await dir.exists()) await dir.create(recursive: true);
    final tmp = File('${dir.path}/watch_progress_queue.json.tmp');
    final finalFile = File('${dir.path}/watch_progress_queue.json');
    final payload = cache.map((op) => op.toJson()).toList(growable: false);
    await tmp.writeAsString(jsonEncode(payload), flush: true);
    await tmp.rename(finalFile.path);
  }
}
