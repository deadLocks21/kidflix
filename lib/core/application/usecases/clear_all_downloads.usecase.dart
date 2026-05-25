import 'package:kidflix/core/domain/services/download.repository.dart';

/// Wipes **all** offline storage in one shot: every downloaded video and
/// every cached video (both kinds — `cache` and `download`), their
/// `.partial` artifacts, and the entire manifest (movies, episodes and
/// series metadata snapshots). Irreversible. Idempotent.
///
/// Backs the parent-facing "Tout effacer" action on the downloads
/// manager — distinct from the per-section "Vider le cache", which spares
/// pinned downloads.
class ClearAllDownloadsUseCase {
  final DownloadRepository _repository;

  const ClearAllDownloadsUseCase(this._repository);

  Future<void> execute() => _repository.deleteAll();
}
