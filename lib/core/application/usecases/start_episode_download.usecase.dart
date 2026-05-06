import 'package:kidflix/core/application/dtos/episode_download.dto.dart';
import 'package:kidflix/core/domain/services/download.repository.dart';

/// Starts an episode download (or attaches to an in-flight one) and
/// returns a stream of [EpisodeDownloadDto] snapshots.
class StartEpisodeDownloadUseCase {
  final DownloadRepository _repository;

  const StartEpisodeDownloadUseCase(this._repository);

  Stream<EpisodeDownloadDto> execute(String episodeId) {
    return _repository
        .downloadEpisode(episodeId)
        .map(EpisodeDownloadDto.fromDomain);
  }
}
