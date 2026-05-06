import 'package:kidflix/core/domain/services/download.repository.dart';

/// Deletes every local artifact of an episode download (`.partial` +
/// `.mp4`) and cancels any in-flight download. Idempotent.
class DeleteEpisodeDownloadUseCase {
  final DownloadRepository _repository;

  const DeleteEpisodeDownloadUseCase(this._repository);

  Future<void> execute(String episodeId) =>
      _repository.deleteEpisode(episodeId);
}
