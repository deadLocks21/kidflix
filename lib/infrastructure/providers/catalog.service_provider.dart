import 'package:kidflix/core/application/services/catalog_application.service.dart';
import 'package:kidflix/core/application/usecases/resolve_continue_watching.usecase.dart';
import 'package:kidflix/infrastructure/providers/catalog.repository_provider.dart';
import 'package:kidflix/infrastructure/providers/series.repository_provider.dart';
import 'package:kidflix/infrastructure/providers/watch_progress.repository_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'catalog.service_provider.g.dart';

@Riverpod(keepAlive: true)
CatalogApplicationService catalogService(Ref ref) {
  final repository = ref.watch(catalogRepositoryProvider);
  final continueWatching = ResolveContinueWatchingUseCase(
    progressRepo: ref.watch(watchProgressRepositoryProvider),
    catalogRepo: repository,
    seriesRepo: ref.watch(seriesRepositoryProvider),
  );
  return CatalogApplicationService(
    repository,
    continueWatching: continueWatching,
  );
}
