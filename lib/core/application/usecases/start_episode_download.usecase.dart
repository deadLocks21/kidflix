import 'dart:async';

import 'package:kidflix/core/application/dtos/episode_download.dto.dart';
import 'package:kidflix/core/domain/model/download_kind.dart';
import 'package:kidflix/core/domain/services/download.repository.dart';
import 'package:kidflix/infrastructure/downloads/download_manifest_entry.dart';
import 'package:kidflix/infrastructure/downloads/manifest_store.dart';

/// Episode counterpart of [StartMovieDownloadUseCase]. Same manifest
/// side effects: capture `triggeredByProfileId` on first invocation,
/// bump `lastPlayedAt = now()` every time.
class StartEpisodeDownloadUseCase {
  final DownloadRepository _repository;
  final DownloadManifestStore _manifest;

  const StartEpisodeDownloadUseCase({
    required DownloadRepository repository,
    required DownloadManifestStore manifest,
  }) : _repository = repository,
       _manifest = manifest;

  Stream<EpisodeDownloadDto> execute(
    String episodeId, {
    String? activeProfileId,
  }) {
    unawaited(_recordPlaybackIntent(episodeId, activeProfileId));
    return _repository
        .downloadEpisode(episodeId)
        .map(EpisodeDownloadDto.fromDomain);
  }

  Future<void> _recordPlaybackIntent(
    String episodeId,
    String? activeProfileId,
  ) async {
    try {
      final now = DateTime.now();
      final existing = await _manifest.findFor(
        mediaId: episodeId,
        isEpisode: true,
      );
      if (existing == null) {
        await _manifest.upsert(
          mediaId: episodeId,
          isEpisode: true,
          entry: DownloadManifestEntry(
            kind: DownloadKind.cache,
            lastPlayedAt: now,
            triggeredByProfileId: activeProfileId,
          ),
        );
        return;
      }
      await _manifest.upsert(
        mediaId: episodeId,
        isEpisode: true,
        entry: existing.copyWith(lastPlayedAt: now),
      );
    } catch (_) {
      // Best-effort.
    }
  }
}
