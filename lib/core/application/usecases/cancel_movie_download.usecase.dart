import 'package:kidflix/core/application/services/logger_application.service.dart';
import 'package:kidflix/core/domain/services/download.repository.dart';

/// Cancels an in-flight download. No-op when no download is active.
class CancelMovieDownloadUseCase {
  final DownloadRepository _repository;
  final LoggerApplicationService _logger;

  const CancelMovieDownloadUseCase(this._repository, this._logger);

  Future<void> execute(String movieId) async {
    await _repository.cancelMovie(movieId);
    await _logger.info(
      'download.canceled',
      attrs: {'content.id': movieId, 'content.type': 'movie'},
    );
  }
}
