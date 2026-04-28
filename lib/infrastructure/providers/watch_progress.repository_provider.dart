import 'package:kidflix/core/domain/services/watch_progress.repository.dart';
import 'package:kidflix/infrastructure/providers/dio.provider.dart';
import 'package:kidflix/infrastructure/watch_progress/dio.watch_progress.repository.dart';
import 'package:kidflix/infrastructure/watch_progress/in_memory.watch_progress.repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'watch_progress.repository_provider.g.dart';

/// Watch-progress repository provider.
///
/// Selects between two implementations based on the compile-time constant
/// `String.fromEnvironment('API_BASE_URL')`:
///
/// - **empty (default)** → [InMemoryWatchProgressRepository] — used by
///   tests, by `flutter run` without flag, and by anyone running
///   offline. Stores progress in a `Map` reset at every app restart.
/// - **non-empty** → [DioWatchProgressRepository] consuming [dioProvider]
///   — hits the three watch-progress endpoints documented in `API.md`
///   § Progression de lecture, with `Authorization: Bearer <jwt>` and
///   `X-Device-Id` headers injected transparently by the
///   `AuthInterceptor`. Used by
///   `flutter run --dart-define=API_BASE_URL=http://localhost:8080`.
///
/// Switching modes requires a full rebuild — `String.fromEnvironment` is
/// evaluated at compile time, not at runtime.
@Riverpod(keepAlive: true)
WatchProgressRepository watchProgressRepository(Ref ref) {
  const baseUrl = String.fromEnvironment('API_BASE_URL');
  if (baseUrl.isEmpty) {
    return InMemoryWatchProgressRepository();
  }
  return DioWatchProgressRepository(dio: ref.watch(dioProvider));
}
