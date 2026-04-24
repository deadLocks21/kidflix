import 'package:kidflix/core/domain/model/movie_download.dart';

/// Contract for downloading a movie's file to local storage and observing
/// its progress.
///
/// The repository SHALL expose a `Stream<MovieDownload>` of progress
/// snapshots with coalesced updates and a `readyToPlay` transition
/// signaling that enough buffer exists for playback to start — even if
/// the download itself is still in progress.
///
/// Implementations live in `lib/infrastructure/downloads/`.
abstract interface class DownloadRepository {
  /// Returns the current state of the download for [movieId], or `null`
  /// when no download has ever been initiated.
  ///
  /// The returned snapshot is reconstructed on demand from the
  /// filesystem + any in-flight state the repository tracks — it is not
  /// an observer (use [download] to attach to live updates).
  Future<MovieDownload?> findByMovieId(String movieId);

  /// Starts a download for [movieId] or attaches to an in-flight one.
  ///
  /// The returned broadcast stream:
  /// - Emits the current state immediately.
  /// - Emits further events on every meaningful status change
  ///   (bytes received, ready-to-play threshold, completion, failure,
  ///   cancellation).
  /// - Throttles pure byte-progress updates (implementation detail).
  /// - Never emits `DownloadStatus.notStarted`.
  /// - Closes on terminal statuses: `complete`, `failed`, `cancelled`.
  ///
  /// Calling `download` on a movie already downloaded yields a single
  /// `complete` event followed by stream closure.
  Stream<MovieDownload> download(String movieId);

  /// Cancels an in-flight download, preserving the `.partial` file for
  /// future resumption. No-op when no download is active.
  Future<void> cancel(String movieId);

  /// Removes all local artifacts for [movieId] and cancels any in-flight
  /// download. Idempotent.
  Future<void> delete(String movieId);
}
