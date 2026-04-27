import 'package:kidflix/core/domain/services/catalog.repository.dart';
import 'package:kidflix/infrastructure/catalog/dio.catalog.repository.dart';
import 'package:kidflix/infrastructure/catalog/in_memory.catalog.repository.dart';
import 'package:kidflix/infrastructure/providers/dio.provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'catalog.repository_provider.g.dart';

/// Catalog repository provider.
///
/// Selects between two implementations based on the compile-time constant
/// `String.fromEnvironment('API_BASE_URL')`:
///
/// - **empty (default)** → [InMemoryCatalogRepository] — used by tests, by
///   `flutter run` without flag, and by anyone running offline.
/// - **non-empty** → [DioCatalogRepository] consuming [dioProvider] — used
///   to talk to the real backend, e.g.
///   `flutter run --dart-define=API_BASE_URL=http://localhost:8080`.
///
/// Switching modes requires a full rebuild — `String.fromEnvironment` is
/// evaluated at compile time, not at runtime.
@Riverpod(keepAlive: true)
CatalogRepository catalogRepository(Ref ref) {
  const baseUrl = String.fromEnvironment('API_BASE_URL');
  if (baseUrl.isEmpty) {
    return InMemoryCatalogRepository();
  }
  return DioCatalogRepository(ref.watch(dioProvider));
}
