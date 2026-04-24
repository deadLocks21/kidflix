import 'package:kidflix/core/domain/services/watch_progress.repository.dart';
import 'package:kidflix/infrastructure/watch_progress/in_memory.watch_progress.repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'watch_progress.repository_provider.g.dart';

/// Watch-progress repository provider.
///
/// Currently always returns [InMemoryWatchProgressRepository]. Will be
/// replaced by an HTTP variant when the backend is available.
@Riverpod(keepAlive: true)
WatchProgressRepository watchProgressRepository(Ref ref) {
  return InMemoryWatchProgressRepository();
}
