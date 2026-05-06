import 'package:kidflix/core/application/dtos/episode_download.dto.dart';
import 'package:kidflix/core/domain/services/download.repository.dart';

/// Returns the current download state for an episode, or `null` when
/// none exists.
class FindEpisodeDownloadUseCase {
  final DownloadRepository _repository;

  const FindEpisodeDownloadUseCase(this._repository);

  Future<EpisodeDownloadDto?> execute(String episodeId) async {
    final domain = await _repository.findForEpisode(episodeId);
    return domain == null ? null : EpisodeDownloadDto.fromDomain(domain);
  }
}
