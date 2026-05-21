import 'package:kidflix/core/domain/services/download.repository.dart';

/// Deletes every local artifact of a download (the media file + any
/// `.partial`) and cancels any in-flight download. Idempotent.
class DeleteMovieDownloadUseCase {
  final DownloadRepository _repository;

  const DeleteMovieDownloadUseCase(this._repository);

  Future<void> execute(String movieId) => _repository.deleteMovie(movieId);
}
