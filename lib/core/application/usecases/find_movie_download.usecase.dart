import 'package:kidflix/core/application/dtos/movie_download.dto.dart';
import 'package:kidflix/core/domain/services/download.repository.dart';

/// Returns the current download state for a movie, or `null` when none
/// exists.
class FindMovieDownloadUseCase {
  final DownloadRepository _repository;

  const FindMovieDownloadUseCase(this._repository);

  Future<MovieDownloadDto?> execute(String movieId) async {
    final domain = await _repository.findByMovieId(movieId);
    return domain == null ? null : MovieDownloadDto.fromDomain(domain);
  }
}
