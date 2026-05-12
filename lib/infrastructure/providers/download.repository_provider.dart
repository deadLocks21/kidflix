import 'package:kidflix/core/domain/services/download.repository.dart';
import 'package:kidflix/infrastructure/downloads/dio.download.repository.dart';
import 'package:kidflix/infrastructure/downloads/in_memory.download.repository.dart';
import 'package:kidflix/infrastructure/providers/api_base_url.provider.dart';
import 'package:kidflix/infrastructure/providers/dio.provider.dart';
import 'package:kidflix/infrastructure/providers/download_manifest_store.provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'download.repository_provider.g.dart';

/// Download repository provider.
///
/// Selects between two implementations based on [apiBaseUrlProvider]:
///
/// - **empty** → [InMemoryDownloadRepository] — used by tests and when no
///   backend has been configured. Streams Big Buck Bunny from archive.org
///   through a private `Dio` (no auth interceptor, so credentials never
///   leak to the third-party CDN).
/// - **non-empty** → [DioDownloadRepository] consuming [dioProvider] —
///   hits `GET /movies/{movie_id}/download` on the Kidflix backend with
///   `Authorization: Bearer <jwt>` and `X-Device-Id` headers injected
///   transparently by the `AuthInterceptor`. The URL is configured by the
///   user via the ⚙ dialog on the phone-entry page.
@Riverpod(keepAlive: true)
DownloadRepository downloadRepository(Ref ref) {
  final manifest = ref.watch(downloadManifestStoreProvider);
  final baseUrl = ref.watch(apiBaseUrlProvider);
  if (baseUrl.isEmpty) {
    return InMemoryDownloadRepository(manifest: manifest);
  }
  return DioDownloadRepository(
    dio: ref.watch(dioProvider),
    manifest: manifest,
  );
}
