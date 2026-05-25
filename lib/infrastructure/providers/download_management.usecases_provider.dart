import 'package:kidflix/core/application/session_state.dart';
import 'package:kidflix/core/application/usecases/clear_all_downloads.usecase.dart';
import 'package:kidflix/core/application/usecases/download_season.usecase.dart';
import 'package:kidflix/core/application/usecases/get_storage_summary.usecase.dart';
import 'package:kidflix/core/application/usecases/list_downloads.usecase.dart';
import 'package:kidflix/core/application/usecases/mark_as_cache.usecase.dart';
import 'package:kidflix/core/application/usecases/mark_as_download.usecase.dart';
import 'package:kidflix/core/application/usecases/run_startup_cache_cleanup.usecase.dart';
import 'package:kidflix/infrastructure/providers/cache_cleanup_preferences.provider.dart';
import 'package:kidflix/infrastructure/providers/catalog.repository_provider.dart';
import 'package:kidflix/infrastructure/providers/device_storage_probe.provider.dart';
import 'package:kidflix/infrastructure/providers/download.repository_provider.dart';
import 'package:kidflix/infrastructure/providers/download_cleanup.service_provider.dart';
import 'package:kidflix/infrastructure/providers/logger.service_provider.dart';
import 'package:kidflix/infrastructure/providers/series.repository_provider.dart';
import 'package:kidflix/infrastructure/providers/session.controller_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'download_management.usecases_provider.g.dart';

@Riverpod(keepAlive: true)
ListDownloadsUseCase listDownloadsUseCase(Ref ref) {
  return ListDownloadsUseCase(
    repository: ref.watch(downloadRepositoryProvider),
    catalog: ref.watch(catalogRepositoryProvider),
    series: ref.watch(seriesRepositoryProvider),
    logger: ref.watch(loggerProvider),
  );
}

@Riverpod(keepAlive: true)
MarkAsDownloadUseCase markAsDownloadUseCase(Ref ref) {
  return MarkAsDownloadUseCase(ref.watch(downloadRepositoryProvider));
}

@Riverpod(keepAlive: true)
MarkAsCacheUseCase markAsCacheUseCase(Ref ref) {
  return MarkAsCacheUseCase(ref.watch(downloadRepositoryProvider));
}

@Riverpod(keepAlive: true)
GetStorageSummaryUseCase getStorageSummaryUseCase(Ref ref) {
  return GetStorageSummaryUseCase(
    probe: ref.watch(deviceStorageProbeProvider),
    repository: ref.watch(downloadRepositoryProvider),
    logger: ref.watch(loggerProvider),
  );
}

@Riverpod(keepAlive: true)
DownloadSeasonUseCase downloadSeasonUseCase(Ref ref) {
  return DownloadSeasonUseCase(
    series: ref.watch(seriesRepositoryProvider),
    downloads: ref.watch(downloadRepositoryProvider),
    logger: ref.watch(loggerProvider),
  );
}

@Riverpod(keepAlive: true)
RunStartupCacheCleanupUseCase runStartupCacheCleanupUseCase(Ref ref) {
  return RunStartupCacheCleanupUseCase(
    service: ref.watch(downloadCleanupServiceProvider),
    preferences: ref.watch(cacheCleanupPreferencesProvider),
    logger: ref.watch(loggerProvider),
  );
}

@Riverpod(keepAlive: true)
ClearAllDownloadsUseCase clearAllDownloadsUseCase(Ref ref) {
  return ClearAllDownloadsUseCase(ref.watch(downloadRepositoryProvider));
}

/// Reactive inventory provider — use cases that mutate the manifest
/// invalidate this provider so the manager UI re-renders.
///
/// Passes every profile id from the active session to the use case so
/// the catalog is queried for each (and the union covers items
/// downloaded by any kid). When no session is available (rare for the
/// manager, which is gated by management mode), falls back to a
/// profile-less call.
@riverpod
Future<DownloadInventory> downloadInventory(Ref ref) async {
  final state = ref.watch(sessionControllerProvider);
  final profileIds = switch (state) {
    Authenticated(:final session) => session.profiles.map((p) => p.id).toList(),
    PinRequired(:final session) => session.profiles.map((p) => p.id).toList(),
    ProfileSelected(:final session) =>
      session.profiles.map((p) => p.id).toList(),
    ManagementPinRequired(:final session) =>
      session.profiles.map((p) => p.id).toList(),
    ManagingProfiles(:final session) =>
      session.profiles.map((p) => p.id).toList(),
    _ => const <String>[],
  };
  return ref
      .watch(listDownloadsUseCaseProvider)
      .execute(profileIds: profileIds);
}

/// Reactive storage summary, same invalidation pattern.
@riverpod
Future<StorageSummary> storageSummary(Ref ref) async {
  return ref.watch(getStorageSummaryUseCaseProvider).execute();
}
