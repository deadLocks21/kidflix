import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kidflix/core/domain/model/download_kind.dart';
import 'package:kidflix/core/domain/services/download.repository.dart';
import 'package:kidflix/infrastructure/downloads/download_cleanup_service.dart';
import 'package:kidflix/infrastructure/downloads/download_manifest_entry.dart';
import 'package:kidflix/infrastructure/downloads/in_memory.download.repository.dart';
import 'package:kidflix/infrastructure/downloads/manifest_store.dart';

void main() {
  late Directory tempDir;
  late JsonFileDownloadManifestStore manifest;
  late InMemoryDownloadRepository repo;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('kidflix-cleanup-');
    Directory('${tempDir.path}/movies').createSync();
    Directory('${tempDir.path}/episodes').createSync();
    manifest = JsonFileDownloadManifestStore(
      resolveDownloadsDir: () async => tempDir,
    );
    repo = InMemoryDownloadRepository(
      dio: Dio(),
      manifest: manifest,
      downloadsDirectory: tempDir,
    );
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  Future<void> seed({
    required String mediaId,
    required bool isEpisode,
    required DownloadKind kind,
    required DateTime? lastPlayedAt,
  }) async {
    final dir = isEpisode ? 'episodes' : 'movies';
    File('${tempDir.path}/$dir/$mediaId.mp4')
        .writeAsBytesSync(List.filled(100, 0));
    await manifest.upsert(
      mediaId: mediaId,
      isEpisode: isEpisode,
      entry: DownloadManifestEntry(
        kind: kind,
        lastPlayedAt: lastPlayedAt,
      ),
    );
  }

  group('RepositoryDownloadCleanupService.runCacheCleanup', () {
    test('removes only stale cache items (kind=cache and lastPlayedAt + 30j < now)',
        () async {
      final now = DateTime.utc(2026, 5, 6, 12);

      await seed(
        mediaId: 'm-keeps-as-download',
        isEpisode: false,
        kind: DownloadKind.download,
        lastPlayedAt: now.subtract(const Duration(days: 60)),
      );
      await seed(
        mediaId: 'm-stale-cache',
        isEpisode: false,
        kind: DownloadKind.cache,
        lastPlayedAt: now.subtract(const Duration(days: 60)),
      );
      await seed(
        mediaId: 'm-fresh-cache',
        isEpisode: false,
        kind: DownloadKind.cache,
        lastPlayedAt: now.subtract(const Duration(days: 5)),
      );
      await seed(
        mediaId: 'e-cache-never-played',
        isEpisode: true,
        kind: DownloadKind.cache,
        lastPlayedAt: null,
      );

      final service = RepositoryDownloadCleanupService(repo);
      final removed = await service.runCacheCleanup(
        olderThan: const Duration(days: 30),
        now: now,
      );

      expect(removed, equals(1));
      expect(
        File('${tempDir.path}/movies/m-keeps-as-download.mp4').existsSync(),
        isTrue,
        reason: 'download kind preserved',
      );
      expect(
        File('${tempDir.path}/movies/m-stale-cache.mp4').existsSync(),
        isFalse,
        reason: 'stale cache deleted',
      );
      expect(
        File('${tempDir.path}/movies/m-fresh-cache.mp4').existsSync(),
        isTrue,
        reason: 'fresh cache preserved',
      );
      expect(
        File('${tempDir.path}/episodes/e-cache-never-played.mp4').existsSync(),
        isTrue,
        reason: 'never-played cache preserved',
      );
    });

    test('is idempotent — second run returns 0', () async {
      final now = DateTime.utc(2026, 5, 6, 12);
      await seed(
        mediaId: 'stale',
        isEpisode: false,
        kind: DownloadKind.cache,
        lastPlayedAt: now.subtract(const Duration(days: 60)),
      );

      final service = RepositoryDownloadCleanupService(repo);
      expect(
        await service.runCacheCleanup(
          olderThan: const Duration(days: 30),
          now: now,
        ),
        equals(1),
      );
      expect(
        await service.runCacheCleanup(
          olderThan: const Duration(days: 30),
          now: now,
        ),
        equals(0),
      );
    });

    test('continues past per-item failure, counts only successes', () async {
      final now = DateTime.utc(2026, 5, 6, 12);
      // Three stale items.
      for (final id in ['a', 'b', 'c']) {
        await seed(
          mediaId: id,
          isEpisode: false,
          kind: DownloadKind.cache,
          lastPlayedAt: now.subtract(const Duration(days: 60)),
        );
      }

      // Wrap repo so deleteMovie('b') throws.
      final wrapped = _ThrowingRepo(repo, throwOnDeleteId: 'b');
      final service = RepositoryDownloadCleanupService(wrapped);

      final removed = await service.runCacheCleanup(
        olderThan: const Duration(days: 30),
        now: now,
      );

      expect(removed, equals(2));
      expect(File('${tempDir.path}/movies/a.mp4').existsSync(), isFalse);
      expect(File('${tempDir.path}/movies/b.mp4').existsSync(), isTrue);
      expect(File('${tempDir.path}/movies/c.mp4').existsSync(), isFalse);
    });

    test('returns 0 when inventory is empty', () async {
      final service = RepositoryDownloadCleanupService(repo);
      expect(
        await service.runCacheCleanup(
          olderThan: const Duration(days: 30),
          now: DateTime.now(),
        ),
        equals(0),
      );
    });
  });
}

/// Wraps a real repo and throws on `deleteMovie(throwOnDeleteId)`.
/// Other methods bounced via [noSuchMethod] using the inner repo as a
/// proxy target.
class _ThrowingRepo implements DownloadRepository {
  final DownloadRepository _inner;
  final String throwOnDeleteId;

  _ThrowingRepo(this._inner, {required this.throwOnDeleteId});

  @override
  Future<void> deleteMovie(String movieId) {
    if (movieId == throwOnDeleteId) {
      throw Exception('simulated IO error');
    }
    return _inner.deleteMovie(movieId);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      Function.apply(_methodFor(invocation.memberName),
          invocation.positionalArguments, invocation.namedArguments);

  Function _methodFor(Symbol name) {
    return switch (name) {
      #findForMovie => _inner.findForMovie,
      #downloadMovie => _inner.downloadMovie,
      #cancelMovie => _inner.cancelMovie,
      #findForEpisode => _inner.findForEpisode,
      #downloadEpisode => _inner.downloadEpisode,
      #cancelEpisode => _inner.cancelEpisode,
      #deleteEpisode => _inner.deleteEpisode,
      #listAll => _inner.listAll,
      #totalBytesOnDisk => _inner.totalBytesOnDisk,
      #setMovieKind => _inner.setMovieKind,
      #setEpisodeKind => _inner.setEpisodeKind,
      #markPlayed => _inner.markPlayed,
      _ => () => throw UnimplementedError('$name'),
    };
  }
}
