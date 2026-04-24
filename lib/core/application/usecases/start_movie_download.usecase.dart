import 'package:kidflix/core/application/dtos/movie_download.dto.dart';
import 'package:kidflix/core/domain/services/download.repository.dart';

/// Starts a movie download (or attaches to an in-flight one) and returns
/// a stream of [MovieDownloadDto] snapshots to the UI.
///
/// Wraps [DownloadRepository.download], mapping each domain snapshot to
/// its DTO at the Application/UI boundary.
class StartMovieDownloadUseCase {
  final DownloadRepository _repository;

  const StartMovieDownloadUseCase(this._repository);

  Stream<MovieDownloadDto> execute(String movieId) {
    return _repository
        .download(movieId)
        .map(MovieDownloadDto.fromDomain);
  }
}
