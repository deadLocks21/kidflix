import 'package:kidflix/core/domain/services/download.repository.dart';

/// Cancels an in-flight episode download. No-op when no download is
/// active.
class CancelEpisodeDownloadUseCase {
  final DownloadRepository _repository;

  const CancelEpisodeDownloadUseCase(this._repository);

  Future<void> execute(String episodeId) =>
      _repository.cancelEpisode(episodeId);
}
