import 'package:kidflix/core/application/usecases/load_track_preferences.usecase.dart';
import 'package:kidflix/core/application/usecases/pick_initial_tracks.usecase.dart';
import 'package:kidflix/core/application/usecases/save_track_preferences.usecase.dart';
import 'package:kidflix/infrastructure/providers/track_preferences.repository_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'track_preferences.usecases_provider.g.dart';

@Riverpod(keepAlive: true)
LoadTrackPreferencesUseCase loadTrackPreferencesUseCase(Ref ref) {
  return LoadTrackPreferencesUseCase(
    ref.watch(trackPreferencesRepositoryProvider),
  );
}

@Riverpod(keepAlive: true)
SaveTrackPreferencesUseCase saveTrackPreferencesUseCase(Ref ref) {
  return SaveTrackPreferencesUseCase(
    ref.watch(trackPreferencesRepositoryProvider),
  );
}

@Riverpod(keepAlive: true)
PickInitialTracksUseCase pickInitialTracksUseCase(Ref ref) {
  return const PickInitialTracksUseCase();
}
