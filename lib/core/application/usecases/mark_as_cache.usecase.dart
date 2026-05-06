import 'package:kidflix/core/domain/model/download_kind.dart';
import 'package:kidflix/core/domain/services/download.repository.dart';

/// Demotes a downloaded item to `kind == cache`, making it eligible
/// again for auto-cleanup. Thin wrapper over
/// [DownloadRepository.setMovieKind] / [DownloadRepository.setEpisodeKind].
class MarkAsCacheUseCase {
  final DownloadRepository _repository;

  const MarkAsCacheUseCase(this._repository);

  Future<void> execute({
    required String mediaId,
    required bool isEpisode,
  }) {
    if (isEpisode) {
      return _repository.setEpisodeKind(mediaId, DownloadKind.cache);
    }
    return _repository.setMovieKind(mediaId, DownloadKind.cache);
  }
}
