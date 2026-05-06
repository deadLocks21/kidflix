import 'package:kidflix/core/domain/services/download_cleanup.service.dart';
import 'package:kidflix/infrastructure/downloads/download_cleanup_service.dart';
import 'package:kidflix/infrastructure/providers/download.repository_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'download_cleanup.service_provider.g.dart';

/// Singleton cleanup service backed by the active [DownloadRepository].
///
/// Consumed by `RunStartupCacheCleanupUseCase` at app boot.
@Riverpod(keepAlive: true)
DownloadCleanupService downloadCleanupService(Ref ref) {
  return RepositoryDownloadCleanupService(
    ref.watch(downloadRepositoryProvider),
  );
}
