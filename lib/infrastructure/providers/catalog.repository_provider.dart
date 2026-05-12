import 'package:kidflix/core/domain/services/catalog.repository.dart';
import 'package:kidflix/infrastructure/catalog/dio.catalog.repository.dart';
import 'package:kidflix/infrastructure/catalog/in_memory.catalog.repository.dart';
import 'package:kidflix/infrastructure/providers/api_base_url.provider.dart';
import 'package:kidflix/infrastructure/providers/dio.provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'catalog.repository_provider.g.dart';

/// Catalog repository provider.
///
/// Selects between two implementations based on [apiBaseUrlProvider]:
///
/// - **empty** → [InMemoryCatalogRepository] — used by tests and when no
///   backend has been configured.
/// - **non-empty** → [DioCatalogRepository] consuming [dioProvider] —
///   talks to the real backend at the URL the user configured via the ⚙
///   dialog on the phone-entry page (persisted in `shared_preferences`).
@Riverpod(keepAlive: true)
CatalogRepository catalogRepository(Ref ref) {
  final baseUrl = ref.watch(apiBaseUrlProvider);
  if (baseUrl.isEmpty) {
    return InMemoryCatalogRepository();
  }
  return DioCatalogRepository(ref.watch(dioProvider));
}
