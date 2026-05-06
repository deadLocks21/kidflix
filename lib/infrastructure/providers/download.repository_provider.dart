import 'package:kidflix/core/domain/services/download.repository.dart';
import 'package:kidflix/infrastructure/downloads/dio.download.repository.dart';
import 'package:kidflix/infrastructure/downloads/in_memory.download.repository.dart';
import 'package:kidflix/infrastructure/providers/dio.provider.dart';
import 'package:kidflix/infrastructure/providers/download_manifest_store.provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'download.repository_provider.g.dart';

/// Download repository provider.
///
/// Selects between two implementations based on the compile-time constant
/// `String.fromEnvironment('API_BASE_URL')`:
///
/// - **empty (default)** → [InMemoryDownloadRepository] — used by tests, by
///   `flutter run` without flag, and by anyone running offline. Streams
///   Big Buck Bunny from archive.org through a private `Dio` (no auth
///   interceptor, so credentials never leak to the third-party CDN).
/// - **non-empty** → [DioDownloadRepository] consuming [dioProvider] —
///   hits `GET /movies/{movie_id}/download` on the Kidflix backend with
///   `Authorization: Bearer <jwt>` and `X-Device-Id` headers injected
///   transparently by the `AuthInterceptor`. Used by
///   `flutter run --dart-define=API_BASE_URL=http://localhost:8080`.
///
/// Switching modes requires a full rebuild — `String.fromEnvironment` is
/// evaluated at compile time, not at runtime.
@Riverpod(keepAlive: true)
DownloadRepository downloadRepository(Ref ref) {
  final manifest = ref.watch(downloadManifestStoreProvider);
  const baseUrl = String.fromEnvironment('API_BASE_URL');
  if (baseUrl.isEmpty) {
    return InMemoryDownloadRepository(manifest: manifest);
  }
  return DioDownloadRepository(
    dio: ref.watch(dioProvider),
    manifest: manifest,
  );
}
