import 'package:kidflix/core/domain/services/catalog.repository.dart';
import 'package:kidflix/infrastructure/catalog/in_memory.catalog.repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'catalog.repository_provider.g.dart';

/// Catalog repository provider.
///
/// Currently always returns [InMemoryCatalogRepository]. Will gain an HTTP
/// variant when the backend is available.
@Riverpod(keepAlive: true)
CatalogRepository catalogRepository(Ref ref) {
  return InMemoryCatalogRepository();
}
