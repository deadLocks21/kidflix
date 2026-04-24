import 'package:kidflix/core/application/services/catalog_application.service.dart';
import 'package:kidflix/infrastructure/providers/catalog.repository_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'catalog.service_provider.g.dart';

@Riverpod(keepAlive: true)
CatalogApplicationService catalogService(Ref ref) {
  final repository = ref.watch(catalogRepositoryProvider);
  return CatalogApplicationService(repository);
}
