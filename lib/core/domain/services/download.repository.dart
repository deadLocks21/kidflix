import 'package:kidflix/core/domain/model/cached_cast_member.dart';
import 'package:kidflix/core/domain/model/download_inventory_record.dart';
import 'package:kidflix/core/domain/model/download_kind.dart';
import 'package:kidflix/core/domain/model/episode_download.dart';
import 'package:kidflix/core/domain/model/movie_download.dart';

/// Contract for downloading a movie or episode video file to local
/// storage and observing its progress.
///
/// The repository exposes **two parallel pipelines** — one per kind —
/// rather than a polymorphic API: the call sites always know statically
/// whether they handle a movie or an episode (the player layer
/// dispatches via the sealed `PlayableMedia`), and the local filesystem
/// paths are inherently namespaced (`/downloads/movies/<id>.<ext>` vs
/// `/downloads/episodes/<id>.<ext>`).
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
/// Inventory & manifest surface (used by the manager page):
///
/// * `listAll` — enumerates every downloaded item present on disk
///   (movies + episodes), decorated with its manifest metadata. Default
///   `kind = cache` and `lastPlayedAt = file.lastModified` when the
///   manifest is absent or has no entry for an item — keeps the legacy
///   filesystem-of-truth model intact.
/// * `totalBytesOnDisk` — sum of file sizes under the downloads
///   directory. Returns `0` when empty/absent. Never throws.
/// * `setMovieKind` / `setEpisodeKind` — promote (cache → download) or
///   demote (download → cache) without touching the file. Idempotent.
/// * `markPlayed` — bumps `lastPlayedAt` to `DateTime.now()` for the
///   given media. Creates a manifest entry if absent.
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

  /// Removes all local artifacts for [movieId] (the media file and any
  /// `.partial`) AND its manifest entry. Cancels any in-flight download.
  /// Idempotent.
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

  /// Removes all local artifacts for [episodeId] (the media file and any
  /// `.partial`) AND its manifest entry. Cancels any in-flight download.
  /// Idempotent.
  Future<void> deleteEpisode(String episodeId);

  // ── Inventory & manifest surface ──────────────────────────────────

  /// Enumerates every downloaded item present on disk under
  /// `${documents}/downloads/{movies,episodes}/`. Returns one record
  /// per media id, with its `bytesOnDisk` (sum of the media file + any
  /// `.partial`) and its manifest metadata. Default `kind = cache`,
  /// `lastPlayedAt = file.lastModified`, others `null` when no
  /// manifest entry exists. Returns an empty list when the directory
  /// is empty or absent. Order is implementation-defined.
  Future<List<DownloadInventoryRecord>> listAll();

  /// Returns the total byte count of all media and `.partial` files
  /// under the downloads directory. Returns `0` when empty/absent.
  /// Never throws.
  Future<int> totalBytesOnDisk();

  /// Wipes **everything**: every media file and `.partial` (movies AND
  /// episodes, regardless of `kind`) plus the entire manifest (movies,
  /// episodes and series metadata snapshots). Cancels any in-flight
  /// download first. Unlike the per-item `delete*`, this spares nothing —
  /// pinned downloads are removed too. Idempotent; best-effort on
  /// per-file errors.
  Future<void> deleteAll();

  /// Sets the [DownloadKind] of the movie identified by [movieId].
  ///
  /// Idempotent: re-setting to the current value is a no-op (no
  /// manifest write). Creates a manifest entry if absent (with
  /// `lastPlayedAt = file.lastModified` when the media file exists).
  /// Other manifest fields (`completedAt`, `lastPlayedAt`,
  /// `triggeredByProfileId`) are preserved verbatim when an entry
  /// already exists.
  Future<void> setMovieKind(String movieId, DownloadKind kind);

  /// Episode counterpart of [setMovieKind].
  Future<void> setEpisodeKind(String episodeId, DownloadKind kind);

  /// Bumps `lastPlayedAt` to `DateTime.now()` for the given media.
  /// Creates a manifest entry with `kind = cache` if absent. Other
  /// fields preserved.
  Future<void> markPlayed({required String mediaId, required bool isEpisode});

  /// Caches display metadata on the manifest entry for the given media.
  /// Used by callers that hold the `Movie` / `Episode` object at the
  /// moment a download is initiated, to bypass the strict age filter on
  /// `/catalog` (cf. `DownloadManifestEntry.cachedTitle` rationale) AND
  /// to feed the offline catalog reconstruction (cf. the full snapshot
  /// fields documented on `DownloadManifestEntry`).
  ///
  /// Creates the manifest entry with `kind = cache` if absent. Other
  /// existing fields preserved. Idempotent at value level — calling
  /// twice with the same metadata is a no-op (no second manifest
  /// write) only if the entry already matches; otherwise an upsert.
  ///
  /// All snapshot fields beyond `title` are optional ; callers pass
  /// what they hold.
  Future<void> cacheMediaMetadata({
    required String mediaId,
    required bool isEpisode,
    required String title,
    String? posterUrl,
    String? parentSeriesTitle,
    String? originalTitle,
    int? year,
    int? durationSeconds,
    String? ageCategory,
    String? synopsis,
    String? tagline,
    String? backdropUrl,
    String? logoUrl,
    List<String>? genres,
    List<String>? director,
    List<CachedCastMember>? topCast,
    String? seriesId,
    int? seasonNumber,
    int? episodeNumber,
  });

  /// Caches the full snapshot of a [Series] under the dedicated `series/`
  /// namespace of the manifest. Used by the series detail modal so the
  /// offline catalog can rebuild the parent series card for any
  /// downloaded episode.
  ///
  /// Creates the entry if absent, replaces only the snapshot fields on
  /// existing entries (preserves any unrelated metadata such as
  /// `triggeredByProfileId` if a future feature stores it).
  Future<void> cacheSeriesMetadata({
    required String seriesId,
    required String title,
    String? posterUrl,
    String? originalTitle,
    int? year,
    String? ageCategory,
    String? synopsis,
    String? tagline,
    String? backdropUrl,
    String? logoUrl,
    List<String>? genres,
    List<String>? director,
    List<CachedCastMember>? topCast,
    int? seasonsCount,
    int? episodesCount,
  });
}
