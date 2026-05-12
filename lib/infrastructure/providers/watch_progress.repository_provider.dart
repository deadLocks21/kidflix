import 'package:kidflix/core/domain/services/watch_progress.repository.dart';
import 'package:kidflix/infrastructure/providers/api_base_url.provider.dart';
import 'package:kidflix/infrastructure/providers/dio.provider.dart';
import 'package:kidflix/infrastructure/watch_progress/dio.watch_progress.repository.dart';
import 'package:kidflix/infrastructure/watch_progress/in_memory.watch_progress.repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'watch_progress.repository_provider.g.dart';

/// Watch-progress repository provider.
///
/// Selects between two implementations based on [apiBaseUrlProvider]:
///
/// - **empty** → [InMemoryWatchProgressRepository] — used by tests and
///   when no backend has been configured. Stores progress in a `Map`
///   reset at every app restart.
/// - **non-empty** → [DioWatchProgressRepository] consuming [dioProvider]
///   — hits the three watch-progress endpoints documented in `API.md`
///   § Progression de lecture, with `Authorization: Bearer <jwt>` and
///   `X-Device-Id` headers injected transparently by the
///   `AuthInterceptor`. The URL is configured by the user via the ⚙
///   dialog on the phone-entry page.
@Riverpod(keepAlive: true)
WatchProgressRepository watchProgressRepository(Ref ref) {
  final baseUrl = ref.watch(apiBaseUrlProvider);
  if (isInMemoryBaseUrl(baseUrl)) {
    return InMemoryWatchProgressRepository();
  }
  return DioWatchProgressRepository(dio: ref.watch(dioProvider));
}
