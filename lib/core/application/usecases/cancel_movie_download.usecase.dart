import 'package:kidflix/core/domain/services/download.repository.dart';

/// Cancels an in-flight download. No-op when no download is active.
class CancelMovieDownloadUseCase {
  final DownloadRepository _repository;

  const CancelMovieDownloadUseCase(this._repository);

  Future<void> execute(String movieId) => _repository.cancelMovie(movieId);
}
