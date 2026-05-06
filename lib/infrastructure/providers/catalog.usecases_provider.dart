import 'package:kidflix/core/application/dtos/catalog_row.dto.dart';
import 'package:kidflix/core/application/dtos/profile.dto.dart';
import 'package:kidflix/core/application/session_state.dart';
import 'package:kidflix/core/application/usecases/list_home_catalog.usecase.dart';
import 'package:kidflix/infrastructure/providers/catalog.service_provider.dart';
import 'package:kidflix/infrastructure/providers/download_management.usecases_provider.dart';
import 'package:kidflix/infrastructure/providers/session.controller_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'catalog.usecases_provider.g.dart';

@Riverpod(keepAlive: true)
ListHomeCatalogUseCase listHomeCatalogUseCase(Ref ref) {
  return ListHomeCatalogUseCase(ref.watch(catalogServiceProvider));
}

/// Builds the list of homepage rows for the active profile. Re-computes
/// automatically when the session transitions to a different profile,
/// and when the download inventory changes (new download, mark as
/// cache, deletion) so the "Téléchargés" row stays in sync.
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
  final useCase = ref.watch(listHomeCatalogUseCaseProvider);
  return useCase.execute(profile, downloads: inventory.downloads);
}
