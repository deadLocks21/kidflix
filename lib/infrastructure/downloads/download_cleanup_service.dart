import 'dart:developer' as developer;

import 'package:kidflix/core/domain/model/download_kind.dart';
import 'package:kidflix/core/domain/services/download.repository.dart';
import 'package:kidflix/core/domain/services/download_cleanup.service.dart';

/// Repository-backed implementation of [DownloadCleanupService]. Uses
/// the existing inventory + delete operations of [DownloadRepository]
/// to enforce the cache-only auto-deletion policy.
///
/// Best-effort and idempotent: per-item delete failures are logged
/// (warning level) and do not abort the loop. The returned count is
/// the number of items actually removed in this pass.
class RepositoryDownloadCleanupService implements DownloadCleanupService {
  final DownloadRepository _repository;

  RepositoryDownloadCleanupService(this._repository);

  @override
  Future<int> runCacheCleanup({
    required Duration olderThan,
    required DateTime now,
  }) async {
    final inventory = await _repository.listAll();
    var deleted = 0;

    for (final record in inventory) {
      if (record.kind != DownloadKind.cache) continue;
      final last = record.lastPlayedAt;
      if (last == null) continue; // never-played entries stay forever
      if (now.difference(last) <= olderThan) continue;

      try {
        if (record.isEpisode) {
          await _repository.deleteEpisode(record.mediaId);
        } else {
          await _repository.deleteMovie(record.mediaId);
        }
        deleted++;
      } catch (e) {
        developer.log(
          'cache cleanup: failed to delete ${record.isEpisode ? "episodes" : "movies"}/${record.mediaId}',
          name: 'kidflix.downloads.cleanup',
          level: 900, // WARNING
          error: e,
        );
      }
    }

    return deleted;
  }
}
