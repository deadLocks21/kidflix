import 'dart:async';

import 'package:kidflix/core/application/dtos/movie_download.dto.dart';
import 'package:kidflix/core/domain/model/download_kind.dart';
import 'package:kidflix/core/domain/services/download.repository.dart';
import 'package:kidflix/infrastructure/downloads/download_manifest_entry.dart';
import 'package:kidflix/infrastructure/downloads/manifest_store.dart';

/// Starts a movie download (or attaches to an in-flight one) and returns
/// a stream of [MovieDownloadDto] snapshots to the UI.
///
/// Wraps [DownloadRepository.downloadMovie], mapping each domain snapshot
/// to its DTO. Also performs two manifest-level side effects, both
/// best-effort and fired-and-forgotten so they never block the stream:
///
/// * Captures `triggeredByProfileId` on the first invocation per media
///   id (subsequent calls preserve the original triggerer).
/// * Bumps `lastPlayedAt = now()` so the cache cleanup window starts
///   from the most recent play.
class StartMovieDownloadUseCase {
  final DownloadRepository _repository;
  final DownloadManifestStore _manifest;

  const StartMovieDownloadUseCase({
    required DownloadRepository repository,
    required DownloadManifestStore manifest,
  }) : _repository = repository,
       _manifest = manifest;

  Stream<MovieDownloadDto> execute(String movieId, {String? activeProfileId}) {
    unawaited(_recordPlaybackIntent(movieId, activeProfileId));
    return _repository.downloadMovie(movieId).map(MovieDownloadDto.fromDomain);
  }

  Future<void> _recordPlaybackIntent(
    String movieId,
    String? activeProfileId,
  ) async {
    try {
      final now = DateTime.now();
      final existing = await _manifest.findFor(
        mediaId: movieId,
        isEpisode: false,
      );
      if (existing == null) {
        await _manifest.upsert(
          mediaId: movieId,
          isEpisode: false,
          entry: DownloadManifestEntry(
            kind: DownloadKind.cache,
            lastPlayedAt: now,
            triggeredByProfileId: activeProfileId,
          ),
        );
        return;
      }
      // Bump lastPlayedAt; preserve triggeredByProfileId (do NOT
      // overwrite the original triggerer).
      await _manifest.upsert(
        mediaId: movieId,
        isEpisode: false,
        entry: existing.copyWith(lastPlayedAt: now),
      );
    } catch (_) {
      // Best-effort.
    }
  }
}
