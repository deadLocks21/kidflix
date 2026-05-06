import 'package:kidflix/core/domain/model/download_kind.dart';
import 'package:kidflix/core/domain/services/download.repository.dart';

/// Promotes a downloaded item to `kind == download` (kept until manual
/// deletion). Thin wrapper over [DownloadRepository.setMovieKind] /
/// [DownloadRepository.setEpisodeKind].
///
/// Idempotent. Does not perform the kids-lock challenge — that is a
/// UI-layer concern (cf. catalog spec). The use case is invoked only
/// after the parent PIN has been verified (or skipped for the parent
/// profile).
class MarkAsDownloadUseCase {
  final DownloadRepository _repository;

  const MarkAsDownloadUseCase(this._repository);

  Future<void> execute({
    required String mediaId,
    required bool isEpisode,
  }) {
    if (isEpisode) {
      return _repository.setEpisodeKind(mediaId, DownloadKind.download);
    }
    return _repository.setMovieKind(mediaId, DownloadKind.download);
  }
}
