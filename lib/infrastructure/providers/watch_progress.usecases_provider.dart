import 'package:kidflix/core/application/usecases/dismiss_continue_watching.usecase.dart';
import 'package:kidflix/core/application/usecases/get_watch_progress.usecase.dart';
import 'package:kidflix/core/application/usecases/save_watch_progress.usecase.dart';
import 'package:kidflix/infrastructure/providers/logger.service_provider.dart';
import 'package:kidflix/infrastructure/providers/watch_progress.repository_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'watch_progress.usecases_provider.g.dart';

@Riverpod(keepAlive: true)
GetWatchProgressUseCase getWatchProgressUseCase(Ref ref) {
  return GetWatchProgressUseCase(ref.watch(watchProgressRepositoryProvider));
}

@Riverpod(keepAlive: true)
SaveWatchProgressUseCase saveWatchProgressUseCase(Ref ref) {
  return SaveWatchProgressUseCase(
    ref.watch(watchProgressRepositoryProvider),
    ref.watch(loggerProvider),
  );
}

@Riverpod(keepAlive: true)
DismissContinueWatchingUseCase dismissContinueWatchingUseCase(Ref ref) {
  return DismissContinueWatchingUseCase(
    ref.watch(watchProgressRepositoryProvider),
  );
}
