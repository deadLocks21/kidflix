import 'package:kidflix/core/application/services/logger_application.service.dart';
import 'package:kidflix/core/domain/services/download.repository.dart';

/// Cancels an in-flight episode download. No-op when no download is
/// active.
class CancelEpisodeDownloadUseCase {
  final DownloadRepository _repository;
  final LoggerApplicationService _logger;

  const CancelEpisodeDownloadUseCase(this._repository, this._logger);

  Future<void> execute(String episodeId) async {
    await _repository.cancelEpisode(episodeId);
    await _logger.info(
      'download.canceled',
      attrs: {'content.id': episodeId, 'content.type': 'episode'},
    );
  }
}
