import 'package:kidflix/core/application/services/catalog_application.service.dart';
import 'package:kidflix/core/application/session_state.dart';
import 'package:kidflix/core/application/usecases/resolve_continue_watching.usecase.dart';
import 'package:kidflix/core/domain/services/catalog.repository.dart';
import 'package:kidflix/infrastructure/catalog/manifest_backed.catalog.repository.dart';
import 'package:kidflix/infrastructure/providers/download_manifest_store.provider.dart';
import 'package:kidflix/infrastructure/providers/series.repository_provider.dart';
import 'package:kidflix/infrastructure/providers/session.controller_provider.dart';
import 'package:kidflix/infrastructure/providers/watch_progress.repository_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'offline_catalog.service_provider.g.dart';

/// Offline counterpart of [catalogRepositoryProvider]: reconstructs a
/// movies-only catalog from the download manifest, with the active
/// profile's age filter (`ageCategory` ∪ `includedLowerAgeCategories`)
/// applied at the repository layer — mirroring the online flow where
/// the backend filters server-side via `X-Profile-Id`.
///
/// Errors when no profile is selected: the home should never be reached
/// in that state.
@Riverpod(keepAlive: true)
CatalogRepository offlineCatalogRepository(Ref ref) {
  final state = ref.watch(sessionControllerProvider);
  if (state is! ProfileSelected) {
    throw StateError('offlineCatalogRepository requires an active profile');
  }
  final manifest = ref.watch(downloadManifestStoreProvider);
  return ManifestBackedCatalogRepository(manifest, state.profile);
}

/// Offline [CatalogApplicationService]: same row-assembly logic as the
/// online service, but reads from the manifest-backed repository and
/// drops the `dynamicMinItems` gate to `0` so even a single downloaded
/// film in a given genre yields a visible row.
@Riverpod(keepAlive: true)
CatalogApplicationService offlineCatalogService(Ref ref) {
  final repository = ref.watch(offlineCatalogRepositoryProvider);
  final watchProgress = ref.watch(watchProgressRepositoryProvider);
  final continueWatching = ResolveContinueWatchingUseCase(
    progressRepo: watchProgress,
    catalogRepo: repository,
    seriesRepo: ref.watch(seriesRepositoryProvider),
  );
  return CatalogApplicationService(
    repository,
    continueWatching: continueWatching,
    watchProgress: watchProgress,
    dynamicMinItems: 0,
  );
}
