import 'package:kidflix/core/domain/services/download.repository.dart';

/// Deletes every local artifact of a download (`.partial` + `.mp4`) and
/// cancels any in-flight download. Idempotent.
class DeleteMovieDownloadUseCase {
  final DownloadRepository _repository;

  const DeleteMovieDownloadUseCase(this._repository);

  Future<void> execute(String movieId) => _repository.delete(movieId);
}
