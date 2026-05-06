## ADDED Requirements

### Requirement: EpisodeDownload domain model

The system SHALL represent an episode download as an immutable Domain
value object `EpisodeDownload` in
`lib/core/domain/model/episode_download.dart` (or co-located with
`movie_download.dart` — implementation choice). Its fields mirror
those of `MovieDownload` exactly, with the identifier renamed:

- `episodeId`: stable identifier of the episode being downloaded
  (string, equals `Episode.id`).
- `status`: `DownloadStatus` enum value (the same enum used by
  `MovieDownload` — no new variant).
- `bytesReceived`: integer.
- `bytesTotal`: nullable integer.
- `localPath`: nullable absolute path.
- `errorMessage`: nullable string, non-null only when `status ==
  failed`.
- `updatedAt`: `DateTime`.

The entity SHALL be equatable by `(episodeId, status, bytesReceived,
updatedAt)`.

`EpisodeDownload` SHALL NOT extend or implement `MovieDownload` (and
vice-versa). The two types are siblings without a shared sealed
parent — see `add-series-viewing/design.md` D-7.

#### Scenario: EpisodeDownload during active download

- **GIVEN** an episode download in progress at 500 KB received out of
  20 MB total
- **THEN** the `EpisodeDownload` has `status == downloading`,
  `bytesReceived == 512_000`, `bytesTotal == 20_971_520`, `localPath
  == null`

#### Scenario: EpisodeDownload at completion

- **GIVEN** an episode download that has just finished
- **THEN** the `EpisodeDownload` has `status == complete`, `localPath`
  pointing to a file ending in `.mp4` (no `.partial` suffix)

#### Scenario: MovieDownload and EpisodeDownload are not assignable

- **GIVEN** a `MovieDownload` instance
- **WHEN** trying to assign it to an `EpisodeDownload` reference
- **THEN** the Dart analyzer rejects the assignment (different types)

---

### Requirement: DownloadRepository.downloadEpisode

The Domain interface `DownloadRepository` SHALL expose a method jumelle
to `downloadMovie` for episodes:

```dart
Stream<EpisodeDownload> downloadEpisode(String episodeId);
```

`downloadEpisode` SHALL behave identically to `downloadMovie` (same
broadcast stream semantics, same `notStarted` exclusion, same
ready-to-play threshold semantics, same terminal-status closure
behavior) on the episode endpoint.

The HTTP implementation SHALL hit `GET /episodes/<episodeId>/download`
documented in `API.md` § Téléchargement de fichier vidéo (jumeau
endpoint of `/movies/<movieId>/download`). All HTTP transport
guarantees are identical: Range requests, HEAD support, header
whitelist (`content-type`, `content-length`, `content-range`,
`accept-ranges`, `last-modified`, `etag`), `cache-control: private,
max-age=3600` from the server.

The local filesystem layout SHALL namespace episode downloads
separately from movie downloads to avoid id collisions:

- `<documentsDir>/downloads/movies/<movieId>.mp4` (existing).
- `<documentsDir>/downloads/episodes/<episodeId>.mp4` (new).

#### Scenario: downloadEpisode emits readyToPlay event

- **GIVEN** an episode download crossing the ready threshold
- **WHEN** subscribing to `downloadEpisode(episodeId)`
- **THEN** the stream emits an `EpisodeDownload` with `status ==
  readyToPlay` and a `localPath` ending in `.mp4.partial` under
  `/downloads/episodes/`

#### Scenario: downloadEpisode hits the episode endpoint, not the movie endpoint

- **GIVEN** the HTTP backend would respond 200 to either
  `/movies/x/download` or `/episodes/x/download`
- **WHEN** `downloadEpisode("x")` is called
- **THEN** the outbound HTTP request path is `/episodes/x/download`
- **AND** NOT `/movies/x/download`

#### Scenario: Episode download file is namespaced

- **GIVEN** a movie with `id == "alpha"` that has been downloaded
- **AND** an episode with `id == "alpha"` (same id, different kind)
  that is being downloaded
- **THEN** the two artifacts coexist on disk at
  `/downloads/movies/alpha.mp4` and
  `/downloads/episodes/alpha.mp4`
- **AND** they do NOT overwrite each other

---

## MODIFIED Requirements

### Requirement: DownloadRepository domain interface

The system SHALL define a Domain interface `DownloadRepository` in
`lib/core/domain/services/download.repository.dart` exposing:

```dart
abstract interface class DownloadRepository {
  // Movie pipeline (renamed methods, semantics unchanged)
  Future<MovieDownload?>   findForMovie(String movieId);
  Stream<MovieDownload>    downloadMovie(String movieId);
  Future<void>             cancelMovie(String movieId);
  Future<void>             deleteMovie(String movieId);

  // Episode pipeline (new)
  Future<EpisodeDownload?> findForEpisode(String episodeId);
  Stream<EpisodeDownload>  downloadEpisode(String episodeId);
  Future<void>             cancelEpisode(String episodeId);
  Future<void>             deleteEpisode(String episodeId);
}
```

The methods are explicitly typed by kind rather than polymorphic on
`PlayableMedia` (see `add-series-viewing/design.md` D-7) — the call
sites always know statically whether they handle a movie or an
episode, and the namespacing of filesystem paths and HTTP routes is
inherently distinct.

The previous methods `download`, `findByMovieId`, `cancel`, `delete`
(taking a movie id) SHALL be renamed to their `Movie`-suffixed
counterparts. Sites that consumed the previous names SHALL be
updated.

The contract semantics for the movie methods are preserved verbatim
from the prior version of this capability — only the names change.

#### Scenario: Renamed movie methods preserve previous behavior

- **GIVEN** a `DownloadRepository` implementation
- **WHEN** `downloadMovie("nemo")` is called
- **THEN** the behavior is identical to what `download("nemo")` was
  in the prior version of this capability (same stream semantics,
  same ready-threshold logic, same terminal-status closure)

#### Scenario: cancelEpisode is a no-op when no download exists

- **GIVEN** no download has been initiated for `episodeId == "ghost"`
- **WHEN** `cancelEpisode("ghost")` is called
- **THEN** the future completes successfully without error
- **AND** no filesystem mutation occurs

#### Scenario: deleteEpisode removes both .partial and .mp4 if present

- **GIVEN** an episode download that has produced a `.partial` file
  but not yet the final `.mp4` (cancelled mid-flight)
- **WHEN** `deleteEpisode(episodeId)` is called
- **THEN** the `.partial` file is removed
- **AND** the future completes successfully

---

### Requirement: HTTP implementation of DownloadRepository (DioDownloadRepository)

The system SHALL provide an HTTP implementation `DioDownloadRepository
implements DownloadRepository` in
`lib/infrastructure/downloads/dio.download.repository.dart` that
calls both `/movies/<id>/download` (existing) and `/episodes/<id>/download`
(new).

`downloadMovie` SHALL preserve its prior contract (route, Range
headers, transcode of failures into `DownloadStatus.failed`,
`cache-control: private, max-age=3600`).

`downloadEpisode` SHALL be a structural twin: same Range / HEAD
handling, same header whitelist, same transcode of `DioException` into
`DownloadStatus.failed`, same proxy follow-of-`302` from the upstream
Infomaniak CDN. The HTTP path is the only difference.

The 403 errors documented in `API.md` are surfaced generically:

- `403 forbidden_age_category` on `/movies/{id}/download` →
  `DownloadStatus.failed` with `errorMessage` set from the response.
- `403 forbidden_age_category` on `/episodes/{id}/download` (the
  parent series is out of profile range) → idem.
- `404 not_found` on either endpoint → idem.

The repository SHALL NOT do retry or backoff. The repository SHALL
NOT log the raw `Authorization` header or any session/profile id.

#### Scenario: downloadEpisode emits failed on 403 forbidden_age_category

- **GIVEN** the backend responds 403 with `{"error": {"code":
  "forbidden_age_category"}}` on `GET /episodes/E1/download`
- **WHEN** subscribing to `downloadEpisode("E1")`
- **THEN** the stream emits one `EpisodeDownload` with `status ==
  failed` and an `errorMessage` deriving from the response body
- **AND** the stream closes after the failure event

#### Scenario: downloadEpisode emits failed on 404 not_found

- **GIVEN** the backend responds 404 on `GET /episodes/E1/download`
- **WHEN** subscribing to `downloadEpisode("E1")`
- **THEN** the stream emits `status == failed` and closes

#### Scenario: HEAD request supported on episode endpoint

- **GIVEN** a Dio call that issues HEAD on `/episodes/E1/download` (used
  by player size probes)
- **WHEN** the call is made
- **THEN** the request method is `HEAD` (not `GET`)
- **AND** the response carries the same headers as a `GET` would
- **AND** the body is empty

#### Scenario: cache-control overrides upstream

- **GIVEN** the upstream Infomaniak responds with `cache-control:
  public, max-age=86400` on either endpoint
- **WHEN** the client receives the response
- **THEN** the response's `cache-control` header (as forwarded by the
  backend) is `private, max-age=3600` (server-side override per
  API.md § Téléchargement)

---

### Requirement: In-memory repository uses a single stub URL for every movie

The in-memory implementation SHALL support both pipelines (movie and
episode) with the same simulation mechanics : an artificial throttled
byte-progression yielding `downloading → readyToPlay → complete`
events on a Stream.

The seed SHALL include at least one episode of the seeded series
(Pingu) reachable via `downloadEpisode("<some_pingu_episode_id>")` so
the smoke-test of the player on episodes is exercisable in
`flutter run` mode without a backend.

#### Scenario: In-memory downloadEpisode emits the standard sequence

- **GIVEN** an `InMemoryDownloadRepository` and an episode id from the
  Pingu seed
- **WHEN** `downloadEpisode(episodeId)` is subscribed to
- **THEN** the stream emits a sequence
  `downloading* → readyToPlay → complete` and then closes
- **AND** all emitted snapshots are `EpisodeDownload` instances (NOT
  `MovieDownload`)
