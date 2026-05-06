import 'package:kidflix/core/domain/model/episode_download.dart';
import 'package:kidflix/core/domain/model/movie_download.dart';

/// Contract for downloading a movie or episode video file to local
/// storage and observing its progress.
///
/// The repository exposes **two parallel pipelines** — one per kind —
/// rather than a polymorphic API: the call sites always know statically
/// whether they handle a movie or an episode (the player layer
/// dispatches via the sealed `PlayableMedia`), and the local filesystem
/// paths are inherently namespaced (`/downloads/movies/<id>.mp4` vs
/// `/downloads/episodes/<id>.mp4`).
///
/// For each pipeline the contract is:
///
/// * `findFor*` — current state on demand from filesystem + in-flight
///   tracking, or `null` when never initiated.
/// * `download*` — broadcast stream emitting status snapshots ; closes on
///   terminal statuses (`complete`, `failed`, `cancelled`) ; never emits
///   `notStarted` ; throttles pure byte-progression updates.
/// * `cancel*` — preserves the `.partial` file for future resumption.
/// * `delete*` — removes all local artifacts and cancels any in-flight
///   download. Idempotent.
///
/// Implementations live in `lib/infrastructure/downloads/`.
abstract interface class DownloadRepository {
  // ── Movie pipeline ────────────────────────────────────────────────

  /// Returns the current state of the movie download for [movieId], or
  /// `null` when no download has ever been initiated.
  Future<MovieDownload?> findForMovie(String movieId);

  /// Starts a movie download for [movieId] or attaches to an in-flight
  /// one. See class doc for emission semantics.
  Stream<MovieDownload> downloadMovie(String movieId);

  /// Cancels an in-flight movie download, preserving the `.partial`
  /// file. No-op when no download is active.
  Future<void> cancelMovie(String movieId);

  /// Removes all local artifacts for [movieId] and cancels any
  /// in-flight download. Idempotent.
  Future<void> deleteMovie(String movieId);

  // ── Episode pipeline ──────────────────────────────────────────────

  /// Returns the current state of the episode download for
  /// [episodeId], or `null` when no download has ever been initiated.
  Future<EpisodeDownload?> findForEpisode(String episodeId);

  /// Starts an episode download for [episodeId] or attaches to an
  /// in-flight one. See class doc for emission semantics.
  Stream<EpisodeDownload> downloadEpisode(String episodeId);

  /// Cancels an in-flight episode download, preserving the `.partial`
  /// file. No-op when no download is active.
  Future<void> cancelEpisode(String episodeId);

  /// Removes all local artifacts for [episodeId] and cancels any
  /// in-flight download. Idempotent.
  Future<void> deleteEpisode(String episodeId);
}
