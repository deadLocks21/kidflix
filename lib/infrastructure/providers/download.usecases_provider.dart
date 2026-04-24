import 'package:kidflix/core/application/dtos/movie_download.dto.dart';
import 'package:kidflix/core/application/usecases/cancel_movie_download.usecase.dart';
import 'package:kidflix/core/application/usecases/delete_movie_download.usecase.dart';
import 'package:kidflix/core/application/usecases/find_movie_download.usecase.dart';
import 'package:kidflix/core/application/usecases/start_movie_download.usecase.dart';
import 'package:kidflix/infrastructure/providers/download.repository_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'download.usecases_provider.g.dart';

@Riverpod(keepAlive: true)
StartMovieDownloadUseCase startMovieDownloadUseCase(Ref ref) {
  return StartMovieDownloadUseCase(ref.watch(downloadRepositoryProvider));
}

@Riverpod(keepAlive: true)
FindMovieDownloadUseCase findMovieDownloadUseCase(Ref ref) {
  return FindMovieDownloadUseCase(ref.watch(downloadRepositoryProvider));
}

@Riverpod(keepAlive: true)
CancelMovieDownloadUseCase cancelMovieDownloadUseCase(Ref ref) {
  return CancelMovieDownloadUseCase(ref.watch(downloadRepositoryProvider));
}

@Riverpod(keepAlive: true)
DeleteMovieDownloadUseCase deleteMovieDownloadUseCase(Ref ref) {
  return DeleteMovieDownloadUseCase(ref.watch(downloadRepositoryProvider));
}

/// Observes the download for [movieId], emitting [MovieDownloadDto]
/// snapshots. Re-subscribes to an in-flight download if one exists,
/// otherwise initiates a new one.
@riverpod
Stream<MovieDownloadDto> movieDownloadStream(Ref ref, String movieId) {
  final useCase = ref.watch(startMovieDownloadUseCaseProvider);
  return useCase.execute(movieId);
}
