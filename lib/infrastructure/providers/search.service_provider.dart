import 'package:kidflix/core/application/services/search_application.service.dart';
import 'package:kidflix/infrastructure/providers/catalog.repository_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'search.service_provider.g.dart';

@Riverpod(keepAlive: true)
SearchApplicationService searchService(Ref ref) {
  final repository = ref.watch(catalogRepositoryProvider);
  return SearchApplicationService(repository);
}
