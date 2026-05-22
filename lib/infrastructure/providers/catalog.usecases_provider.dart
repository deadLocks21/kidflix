import 'dart:async';
import 'dart:math';

import 'package:kidflix/core/application/dtos/catalog_row.dto.dart';
import 'package:kidflix/core/application/dtos/profile.dto.dart';
import 'package:kidflix/core/application/session_state.dart';
import 'package:kidflix/core/application/usecases/list_home_catalog.usecase.dart';
import 'package:kidflix/core/application/usecases/refresh_download_snapshots.usecase.dart';
import 'package:kidflix/core/domain/model/favorite.dart';
import 'package:kidflix/infrastructure/providers/catalog.repository_provider.dart';
import 'package:kidflix/infrastructure/providers/catalog.service_provider.dart';
import 'package:kidflix/infrastructure/providers/connectivity.service_provider.dart';
import 'package:kidflix/infrastructure/providers/download.repository_provider.dart';
import 'package:kidflix/infrastructure/providers/download_management.usecases_provider.dart';
import 'package:kidflix/infrastructure/providers/download_manifest_store.provider.dart';
import 'package:kidflix/infrastructure/providers/favorites.controller_provider.dart';
import 'package:kidflix/infrastructure/providers/logger.service_provider.dart';
import 'package:kidflix/infrastructure/providers/offline_catalog.service_provider.dart';
import 'package:kidflix/infrastructure/providers/series.repository_provider.dart';
import 'package:kidflix/infrastructure/providers/session.controller_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'catalog.usecases_provider.g.dart';

@Riverpod(keepAlive: true)
ListHomeCatalogUseCase listHomeCatalogUseCase(Ref ref) {
  return ListHomeCatalogUseCase(
    ref.watch(catalogServiceProvider),
    ref.watch(loggerProvider),
  );
}

@Riverpod(keepAlive: true)
RefreshDownloadSnapshotsUseCase refreshDownloadSnapshotsUseCase(Ref ref) {
  return RefreshDownloadSnapshotsUseCase(
    catalog: ref.watch(catalogRepositoryProvider),
    series: ref.watch(seriesRepositoryProvider),
    downloads: ref.watch(downloadRepositoryProvider),
    manifest: ref.watch(downloadManifestStoreProvider),
  );
}

/// Offline counterpart of [listHomeCatalogUseCaseProvider]. Same use
/// case type, but wired on top of the manifest-backed catalog service.
@Riverpod(keepAlive: true)
ListHomeCatalogUseCase listOfflineHomeCatalogUseCase(Ref ref) {
  return ListHomeCatalogUseCase(
    ref.watch(offlineCatalogServiceProvider),
    ref.watch(loggerProvider),
  );
}

/// Session-stable seed for the home shuffle. `keepAlive` so it survives
/// across `homeCatalogRows` rebuilds — without this, every invalidation
/// (e.g. `downloadInventoryProvider` after starting a download) would
/// reshuffle every row, making the home appear to "reset" on a tap.
/// Refreshes only on full app restart.
@Riverpod(keepAlive: true)
int homeShuffleSeed(Ref ref) => Random().nextInt(1 << 32);

/// Builds the list of homepage rows for the active profile. Re-computes
/// automatically when the session transitions to a different profile,
/// when the download inventory changes (new download, mark as cache,
/// deletion) so the "Téléchargés" row stays in sync, and when the
/// connectivity state flips (online ↔ offline) so the source swaps.
///
/// Source selection:
/// - **Online** → standard [listHomeCatalogUseCaseProvider], hits the
///   backend. If the network call throws, we fall back to the offline
///   use case so the user still sees their downloaded items rather than
///   an error screen.
/// - **Offline** → [listOfflineHomeCatalogUseCaseProvider], reconstructs
///   rows from the download manifest. Movies only (cf.
///   `ManifestBackedCatalogRepository` doc).
///
/// Expects the session to be in [ProfileSelected] — the router ensures the
/// home page is only mounted in that state.
@riverpod
Future<List<CatalogRowDto>> homeCatalogRows(Ref ref) async {
  final state = ref.watch(sessionControllerProvider);
  if (state is! ProfileSelected) {
    throw StateError('homeCatalogRows requires an active profile');
  }
  final profile = ProfileDto.fromDomain(state.profile);
  final inventory = await ref.watch(downloadInventoryProvider.future);
  final seed = ref.watch(homeShuffleSeedProvider);
  // Favorites feed the "Ma liste" row. The controller is keepAlive so
  // a transient AsyncLoading on startup is rare ; treat unresolved
  // states as an empty list rather than blocking the whole home.
  final favorites = ref
      .watch(favoritesControllerProvider)
      .maybeWhen(data: (v) => v, orElse: () => const <Favorite>[]);
  final online = ref
      .watch(connectivityProvider)
      .maybeWhen(data: (v) => v, orElse: () => true);
  if (!online) {
    final offline = ref.watch(listOfflineHomeCatalogUseCaseProvider);
    return offline.execute(
      profile,
      downloads: inventory.downloads,
      favorites: favorites,
      shuffleSeed: seed,
    );
  }
  final useCase = ref.watch(listHomeCatalogUseCaseProvider);
  final rows = await useCase.execute(
    profile,
    downloads: inventory.downloads,
    favorites: favorites,
    shuffleSeed: seed,
  );
  // Connectivity says online and the call succeeded — fire-and-forget
  // backfill of any manifest entries that lack the full snapshot so
  // the offline home stays accurate. Pass every profile id of the
  // session so films downloaded for OTHER profiles (filtered out of
  // this profile's catalog response) also get refreshed.
  final session = state.session;
  final allProfileIds = session.profiles.map((p) => p.id).toList();
  unawaited(
    ref
        .read(refreshDownloadSnapshotsUseCaseProvider)
        .execute(profileIds: allProfileIds),
  );
  return rows;
  // No silent fall-through to the offline catalog on online failure:
  // that masked real backend / network errors as an empty home and
  // left the user with no retry affordance. The exception propagates
  // and `_ErrorState` shows "Réessayer".
}
