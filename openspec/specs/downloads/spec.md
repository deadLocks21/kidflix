# downloads Specification

## Purpose
TBD - created by archiving change add-video-playback-and-downloads. Update Purpose after archive.
## Requirements
### Requirement: MovieDownload domain model

The system SHALL represent a download as an immutable Domain value object
`MovieDownload` with the following fields:

- `movieId`: stable identifier of the movie being downloaded (string, equals
  `Movie.id`).
- `status`: `DownloadStatus` enum value (see below).
- `bytesReceived`: integer count of bytes written to disk so far.
- `bytesTotal`: nullable integer total size in bytes (null when the HTTP
  response does not provide `Content-Length`).
- `localPath`: nullable absolute path to the file on disk. Null while
  `status == downloading` before the ready threshold. Non-null from
  `readyToPlay` onward, pointing to the `.partial` file during `readyToPlay`
  and to the final `.mp4` file after `complete`.
- `errorMessage`: nullable string, non-null only when `status == failed`.
- `updatedAt`: `DateTime` of the most recent status change.

The `DownloadStatus` enum SHALL contain exactly the following variants, in
this documented progression:

- `notStarted` — no download has ever been initiated for this movie.
  Returned by `findByMovieId` only; never emitted by the download stream.
- `downloading` — bytes are actively being received, `localPath` is null,
  the ready threshold has not been reached yet.
- `readyToPlay` — the ready threshold has been reached, `localPath` points
  to the `.partial` file, playback can start. Download continues to append
  to the same file.
- `complete` — download finished successfully, file has been renamed from
  `.partial` to `.mp4`, `localPath` points to the final file.
- `failed` — download failed. `errorMessage` is non-null. `localPath` may
  be null or may point to an incomplete `.partial` kept for future
  resumption.
- `cancelled` — the user cancelled the download. `localPath` may point to
  an incomplete `.partial` kept for future resumption.

The entity SHALL be equatable by `(movieId, status, bytesReceived,
updatedAt)` combined.

#### Scenario: Download snapshot during active download

- **GIVEN** a download in progress at 1.2 MB received out of 150 MB total
- **THEN** the `MovieDownload` has `status == downloading`, `bytesReceived == 1_258_291`, `bytesTotal == 157_286_400`, `localPath == null`

#### Scenario: Download snapshot at ready-to-play threshold

- **GIVEN** a download that has just crossed the ready threshold
- **THEN** the `MovieDownload` has `status == readyToPlay`, `localPath` is the path to the `.partial` file (ending in `.mp4.partial`)

#### Scenario: Download snapshot at completion

- **GIVEN** a download that has just finished
- **THEN** the `MovieDownload` has `status == complete`, `localPath` is the path to the final file (ending in `.mp4`, no `.partial` suffix)
- **AND** `bytesReceived == bytesTotal` when `bytesTotal` is non-null

---

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

### Requirement: Ready-to-play threshold based on bytes received

The system SHALL emit `DownloadStatus.readyToPlay` on the download stream
when **both** of the following conditions are met for the first time during
the download:

- `bytesReceived >= 2 * 1024 * 1024` (2 MiB).
- If `bytesTotal` is non-null: `bytesReceived >= bytesTotal * 0.03`
  (3% of the total size).

If `bytesTotal` is null (no `Content-Length` header on the response), the
3% condition SHALL be ignored and the 2 MiB threshold alone triggers
`readyToPlay`.

The `readyToPlay` status is emitted exactly once per download session. All
subsequent progress events remain in `downloading` semantically, **but**
the repository MAY coalesce them into a single `downloading`-like status
on the stream if the only change is the byte count — the implementation
detail is that the stream emits `MovieDownload` snapshots with the
accurate `bytesReceived` at a throttled rate (see throttling requirement).

Once `readyToPlay` has been emitted, `localPath` on every subsequent event
SHALL be non-null and stable (pointing to the `.partial` file), until the
`complete` event where it switches to the final `.mp4` file.

#### Scenario: Ready-to-play on a 150 MB file

- **GIVEN** a download with `bytesTotal = 157_286_400` (≈ 150 MB)
- **WHEN** `bytesReceived` reaches `4_718_592` (≈ 4.5 MB, > 2 MiB and > 3%)
- **THEN** a `MovieDownload` with `status == readyToPlay` is emitted on the stream

#### Scenario: Ready-to-play on an unknown-size file

- **GIVEN** a download whose response has no `Content-Length` header (`bytesTotal == null`)
- **WHEN** `bytesReceived` reaches `2_097_152` (2 MiB)
- **THEN** a `MovieDownload` with `status == readyToPlay` is emitted on the stream

#### Scenario: Very small file never reaches 3% before 2 MiB

- **GIVEN** a download with `bytesTotal = 50_000_000` (50 MB)
- **WHEN** `bytesReceived` reaches `2_097_152` (2 MiB, about 4.2%)
- **THEN** both conditions are satisfied simultaneously
- **AND** `readyToPlay` is emitted

---

### Requirement: Progress stream events are throttled

The download stream SHALL emit progress events (where only
`bytesReceived` and `updatedAt` change) at a maximum rate of **4 events
per second**. Intermediate byte updates SHALL be coalesced — the next
emitted event carries the most recent `bytesReceived`.

Events that change `status` (entering `readyToPlay`, `complete`, `failed`,
`cancelled`) SHALL bypass throttling and be emitted immediately.

This throttling SHALL be applied by the `InMemoryDownloadRepository`
(responsibility of the infrastructure layer). The Domain interface does
not specify it — future HTTP impls may choose a different rate.

#### Scenario: Byte updates throttled to 4 Hz

- **GIVEN** a download receiving data at a rate that would emit 60 progress updates per second
- **WHEN** the stream is observed for 1 second
- **THEN** at most 4 events are received
- **AND** the last received event reflects the most recent `bytesReceived`

#### Scenario: Status changes are not throttled

- **GIVEN** a download progressing at high throughput
- **WHEN** the `readyToPlay` threshold is crossed between two throttled ticks
- **THEN** the `readyToPlay` event is emitted immediately, not at the next tick

---

### Requirement: Concurrent download calls on the same movieId are deduplicated

The `DownloadRepository` SHALL ensure that, at any given time, at most
**one** actual network request is in flight per `movieId`. A second call
to `download(movieId)` while a download is already active SHALL return a
stream observing the existing download, not initiate a new one.

Concurrent calls for **different** `movieId`s SHALL proceed independently
and in parallel. No cross-movie queue is enforced at the repository layer
— if the caller triggers 10 downloads at once, 10 downloads run in
parallel (dedup is per-movieId only).

#### Scenario: Duplicate download call returns the existing stream

- **GIVEN** a download for `movieId "abc"` has just started
- **WHEN** `download("abc")` is called a second time before the first completes
- **THEN** no second network request is initiated
- **AND** the second call returns a stream synchronized with the first

#### Scenario: Parallel downloads of different movies proceed independently

- **GIVEN** no active downloads
- **WHEN** `download("abc")` and `download("xyz")` are called in the same tick
- **THEN** two independent streams are returned
- **AND** both downloads proceed in parallel with no cross-influence

---

### Requirement: Local file layout uses a .partial suffix during download

The `DownloadRepository` implementation SHALL store downloaded bytes under
the app documents directory (obtained via `path_provider`) in a dedicated
`downloads` subdirectory: `${applicationDocumentsDirectory}/downloads/`.

During download, bytes SHALL be written to a file named
`${movieId}.mp4.partial`. Upon successful completion (all bytes received
and verified against `bytesTotal` when non-null), the repository SHALL
rename the file to `${movieId}.mp4` **before** emitting the `complete`
event.

The `.partial` suffix SHALL NOT appear on disk once a download is
`complete`. A file ending in `.mp4` (without `.partial`) is the
authoritative marker that `findByMovieId` SHALL use to detect a fully
downloaded movie across app restarts.

If a `.partial` file exists at startup (from an incomplete session),
`findByMovieId` SHALL return a `MovieDownload` with `status == failed`
(or `cancelled` — implementation-defined semantic for "interrupted")
and `localPath` pointing to the `.partial`. A subsequent `download` call
SHALL resume from the partial file via a `Range` request (see resumption
requirement).

#### Scenario: Final file has no .partial suffix

- **GIVEN** a download for `movieId = "abc"` just completed
- **THEN** the file on disk is `${documents}/downloads/abc.mp4`
- **AND** no `${documents}/downloads/abc.mp4.partial` exists

#### Scenario: findByMovieId detects a complete download across restart

- **GIVEN** the app was closed after a download of `"abc"` reached `complete`
- **AND** the file `${documents}/downloads/abc.mp4` still exists
- **WHEN** `findByMovieId("abc")` is called after a cold start
- **THEN** the returned `MovieDownload` has `status == complete` and `localPath` points to the existing file

#### Scenario: findByMovieId detects an interrupted download across restart

- **GIVEN** the app crashed during a download of `"abc"`
- **AND** the file `${documents}/downloads/abc.mp4.partial` still exists with 30 MB
- **WHEN** `findByMovieId("abc")` is called after a cold start
- **THEN** the returned `MovieDownload` has `status` in `{failed, cancelled}`
- **AND** `localPath` points to the `.partial` file
- **AND** `bytesReceived == 30_000_000` (file size on disk)

---

### Requirement: Interrupted downloads resume via HTTP Range

The repository SHALL resume an interrupted download via an HTTP
`Range: bytes=X-` header when `download(movieId)` is called and a
`.partial` file already exists on disk from a prior interrupted session,
where `X` is the current size of the `.partial` file. The file SHALL be
opened in append mode and new bytes appended without truncating prior
content.

If the server does not honor the `Range` header (returns 200 instead of
206), the repository SHALL restart the download from scratch (truncate
the `.partial` file and begin at byte 0).

`bytesReceived` on the first emitted `MovieDownload` of a resumed
download SHALL reflect the **total** bytes on disk (prior + newly
downloaded), not just the newly downloaded bytes.

#### Scenario: Resume from 30 MB on a 150 MB file

- **GIVEN** a `.partial` file exists at 30 MB for `movieId "abc"`
- **WHEN** `download("abc")` is called
- **THEN** the HTTP request includes `Range: bytes=30000000-`
- **AND** the first emitted event has `bytesReceived == 30_000_000`
- **AND** subsequent events increment `bytesReceived` past 30 MB

#### Scenario: Server ignores Range header, download restarts

- **GIVEN** a `.partial` file exists at 30 MB
- **AND** the server responds with HTTP 200 (ignores Range)
- **WHEN** `download("abc")` proceeds
- **THEN** the `.partial` file is truncated to 0 bytes
- **AND** the first emitted event has `bytesReceived == 0`

---

### Requirement: Cancellation stops the download and preserves the partial file

Calling `cancel(movieId)` while a download is active SHALL:

1. Abort the in-flight HTTP request.
2. Emit a final `MovieDownload` event with `status == cancelled` and
   `localPath` pointing to the current `.partial` file.
3. Close the stream.
4. Preserve the `.partial` file on disk for future resumption.

Calling `cancel(movieId)` when no download is active SHALL be a no-op
(no exception, no event).

#### Scenario: Cancellation emits cancelled and preserves partial

- **GIVEN** a download for `"abc"` is in progress with 10 MB received
- **WHEN** `cancel("abc")` is called
- **THEN** a `cancelled` event is emitted on the stream
- **AND** the stream closes
- **AND** the file `${documents}/downloads/abc.mp4.partial` still exists with 10 MB

#### Scenario: Cancellation on a non-active movieId is a no-op

- **GIVEN** no active download for `"unknown"`
- **WHEN** `cancel("unknown")` is called
- **THEN** the call completes without error
- **AND** no event is emitted

---

### Requirement: Deletion removes all local artifacts and cancels any in-flight download

Calling `delete(movieId)` SHALL:

1. If a download is in flight, cancel it (equivalent to `cancel`).
2. Remove both `${movieId}.mp4` and `${movieId}.mp4.partial` from disk
   if they exist.
3. Clear any cached state the repository holds for this `movieId`.

`delete` SHALL be idempotent: calling it on a `movieId` with no files
and no active download SHALL complete successfully without emitting any
event.

#### Scenario: Delete a completed movie

- **GIVEN** `${documents}/downloads/abc.mp4` exists
- **WHEN** `delete("abc")` is called
- **THEN** the file is removed from disk
- **AND** a subsequent `findByMovieId("abc")` returns `null`

#### Scenario: Delete an in-flight download

- **GIVEN** a download for `"abc"` is in progress, active stream observed
- **WHEN** `delete("abc")` is called
- **THEN** the stream emits `cancelled` and closes
- **AND** the `.partial` file is also removed (unlike `cancel` which preserves it)

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

### Requirement: Shared HTTP download streaming helper

The system SHALL expose a public top-level function `streamHttpDownload` in `lib/infrastructure/downloads/http_download_stream.dart` that encapsulates the HTTP-streaming-to-filesystem download loop shared by every implementation of `DownloadRepository`.

The signature SHALL be:

```dart
Stream<MovieDownload> streamHttpDownload({
  required Dio dio,
  required String url,
  required String movieId,
  required Directory downloadsDir,
  required CancelToken cancelToken,
  required bool Function() isCancelled,
});
```

Parameters:

- `dio` — the HTTP client to use. Each caller provides its own. The helper SHALL NOT instantiate or import any global `Dio` (this is the structural guarantee that an in-memory caller can pass an unauthenticated `Dio` to a third-party URL without leaking credentials, cf. design.md decision 2).
- `url` — the target URL. May be absolute (e.g. archive.org) or relative to `dio.options.baseUrl` (e.g. `/movies/abc/download`). Both forms SHALL work without modification to the helper.
- `movieId` — the stable movie identifier used to compute the on-disk file paths.
- `downloadsDir` — the directory under which `${movieId}.mp4` and `${movieId}.mp4.partial` live. The helper SHALL create the directory if missing.
- `cancelToken` — a Dio `CancelToken` the caller controls. When the caller cancels it, the helper SHALL detect the cancellation, emit a final `cancelled` event, and close the stream.
- `isCancelled` — a callback the caller provides for the helper to read its cancellation state lazily, distinguishing user-initiated cancellation from a `DioException` that happens to be a `CancelToken.isCancel`.

The helper SHALL:

1. Inspect `${downloadsDir}/${movieId}.mp4` first. If it exists, emit a single `MovieDownload` with `status == complete`, `bytesReceived == bytesTotal == file size`, `localPath` pointing to the file, and close the stream — without issuing any HTTP request.
2. Otherwise, inspect `${downloadsDir}/${movieId}.mp4.partial`. If it exists with size `N > 0`, prepare to issue the request with header `Range: bytes=$N-`.
3. Issue `dio.get(url, options: Options(responseType: ResponseType.stream, headers: {if (rangeStart > 0) 'Range': 'bytes=$rangeStart-'}), cancelToken: cancelToken)`. The `responseType: stream` override SHALL apply per-request and SHALL NOT mutate `Dio.options.responseType` (so other `Dio.get` callers on the same instance are unaffected). The helper SHALL NOT override `receiveTimeout` — in dio 5.x with `ResponseType.stream`, the receive timeout is applied per-event via `Stream.timeout()` (gap between consecutive chunks), not on the total transfer duration. The 30s default of the central `dioProvider` is therefore safe for streaming downloads of any size, provided no chunk gap exceeds 30s. Setting `receiveTimeout: Duration.zero` SHALL NOT be used: dio 5.x interprets it as a 0 ms timeout, causing immediate failure.
4. If the response status code is `206 Partial Content`, append to the existing `.partial` file starting at `rangeStart`. If the response status code is `200 OK` while a `.partial` file existed, truncate the `.partial` file to 0 bytes and start over — the server has not honored the `Range`.
5. Compute `bytesTotal` from response headers: prefer `Content-Range: bytes start-end/total` (regex `/(\d+)\s*$`), fall back to `Content-Length + rangeStart`, fall back to `null`.
6. Open the `.partial` file in write-only-append mode. Emit an initial `MovieDownload` with `status == downloading`, `bytesReceived == rangeStart` (or `0` if Range was rejected), `bytesTotal` as resolved, `localPath == null`.
7. Iterate the response stream chunk-by-chunk, append each chunk to the sink, and increment `bytesReceived`. On the first iteration where the `readyToPlay` threshold is satisfied (cf. existing requirement *Ready-to-play threshold based on bytes received*), emit a `readyToPlay` event with `localPath == ${downloadsDir}/${movieId}.mp4.partial`.
8. After `readyToPlay` has been emitted, throttle subsequent progress events at `4 Hz` (250 ms minimum between byte-only updates) per the existing requirement *Progress stream events are throttled*. The throttled event SHALL carry the most recent `bytesReceived`, `status == readyToPlay`, and `localPath` pointing to the `.partial`.
9. On normal completion, flush and close the sink, rename `${downloadsDir}/${movieId}.mp4.partial` to `${downloadsDir}/${movieId}.mp4`, emit a final `complete` event with `localPath` pointing to the renamed file, and close the stream.
10. On cancellation (either `isCancelled()` returns `true` or the `cancelToken` was cancelled), flush and close the sink, preserve the `.partial` file, emit a final `cancelled` event with `localPath` pointing to the `.partial`, and close the stream.
11. On any other error (network, malformed response, IO error), flush and close the sink, preserve the `.partial` file, emit a final `failed` event with `errorMessage` set to the exception's message, and close the stream.

The helper SHALL be the single source of truth for the download loop: no other implementation of `DownloadRepository` SHALL re-implement the threshold, throttle, rename, or `Range` logic. Any future repository (in-memory, HTTP, or any new transport) SHALL delegate its `download(movieId)` to this helper.

The helper SHALL NOT log raw response bodies, the `Authorization` header, or the JWT at any log level.

#### Scenario: Helper streams a fresh download to completion

- **GIVEN** no prior `.partial` or `.mp4` exists for `movieId "abc"`
- **AND** a `Dio` configured with a `_FakeAdapter` returning a 200 response with `Content-Length: 10485760` (10 MB) and a stream of bytes
- **WHEN** the helper is called with this `Dio`, an absolute URL, `movieId "abc"`, and a temp `downloadsDir`
- **THEN** the stream emits `downloading` initially with `bytesReceived == 0`
- **AND** at some point emits `readyToPlay` with `localPath` ending in `abc.mp4.partial`
- **AND** the final event is `complete` with `localPath` ending in `abc.mp4` (no `.partial` suffix)
- **AND** the file `${downloadsDir}/abc.mp4` exists with 10485760 bytes
- **AND** the file `${downloadsDir}/abc.mp4.partial` does not exist

#### Scenario: Helper resumes from an existing .partial via Range

- **GIVEN** a `.partial` file exists at `${downloadsDir}/abc.mp4.partial` with 30000000 bytes
- **AND** a `Dio` configured to return 206 Partial Content with `Content-Range: bytes 30000000-99999999/100000000`
- **WHEN** the helper is called for `movieId "abc"`
- **THEN** the outbound HTTP request includes header `Range: bytes=30000000-`
- **AND** the first emitted event has `bytesReceived == 30000000` and `bytesTotal == 100000000`

#### Scenario: Helper restarts when server ignores Range

- **GIVEN** a `.partial` file exists at 30000000 bytes
- **AND** the `Dio` returns 200 OK (Range header ignored) with full content
- **WHEN** the helper is called
- **THEN** the `.partial` file is truncated to 0 bytes
- **AND** the first emitted event has `bytesReceived == 0`

#### Scenario: Helper detects an existing complete .mp4 without HTTP

- **GIVEN** the file `${downloadsDir}/abc.mp4` already exists with 10000000 bytes
- **WHEN** the helper is called for `movieId "abc"`
- **THEN** no HTTP request is issued by the underlying `Dio` (verifiable via the `_FakeAdapter` request count)
- **AND** the stream emits a single `complete` event with `bytesReceived == bytesTotal == 10000000`
- **AND** the stream then closes

#### Scenario: Helper override does not mutate Dio defaults

- **GIVEN** a `Dio` with `options.responseType == ResponseType.json`
- **WHEN** the helper completes a successful download using this `Dio`
- **THEN** after the call, `dio.options.responseType` is still `ResponseType.json`

#### Scenario: Helper emits failed on network error and preserves .partial

- **GIVEN** a `.partial` file exists at 5000000 bytes
- **AND** the `Dio` raises a `DioException` of type `connectionError` mid-stream
- **WHEN** the helper is iterating the response
- **THEN** the stream emits a final `failed` event with `errorMessage` non-null
- **AND** the `.partial` file still exists with at least 5000000 bytes

#### Scenario: Helper emits cancelled when the cancel token is triggered

- **GIVEN** a download is in progress at 5000000 bytes received
- **WHEN** the caller cancels its `CancelToken`
- **THEN** the stream emits a final `cancelled` event with `localPath` pointing to the `.partial`
- **AND** the `.partial` file still exists on disk

---

### Requirement: Shared on-disk download inspector

The system SHALL expose a public top-level function `inspectDownloadOnDisk` in `lib/infrastructure/downloads/http_download_stream.dart` (same file as `streamHttpDownload`) that encapsulates the filesystem-only logic shared by every `DownloadRepository.findByMovieId` implementation:

```dart
Future<MovieDownload?> inspectDownloadOnDisk({
  required String movieId,
  required Directory downloadsDir,
});
```

The function SHALL:

1. Test for `${downloadsDir}/${movieId}.mp4`. If it exists, return a `MovieDownload` with `status == complete`, `bytesReceived == bytesTotal == file size`, `localPath == file.path`, `updatedAt == file.lastModified()`.
2. Otherwise, test for `${downloadsDir}/${movieId}.mp4.partial`. If it exists, return a `MovieDownload` with `status == cancelled`, `bytesReceived == file size`, `bytesTotal == null`, `localPath == file.path`, `updatedAt == file.lastModified()`.
3. Otherwise, return `null`.

The function SHALL NOT issue any HTTP request. It SHALL NOT depend on any active in-process state — it inspects the filesystem only.

The function SHALL be called by every `DownloadRepository.findByMovieId(movieId)` implementation as the second step (after consulting any in-process cache of active downloads).

#### Scenario: Inspector returns complete for an existing .mp4

- **GIVEN** the file `${downloadsDir}/abc.mp4` exists with 50000000 bytes
- **WHEN** `inspectDownloadOnDisk(movieId: "abc", downloadsDir: …)` is called
- **THEN** the result is a `MovieDownload` with `status == DownloadStatus.complete`, `bytesReceived == 50000000`, `bytesTotal == 50000000`, `localPath` ending in `abc.mp4`

#### Scenario: Inspector returns cancelled for an existing .partial

- **GIVEN** only the file `${downloadsDir}/abc.mp4.partial` exists with 30000000 bytes
- **WHEN** `inspectDownloadOnDisk(movieId: "abc", downloadsDir: …)` is called
- **THEN** the result is a `MovieDownload` with `status == DownloadStatus.cancelled`, `bytesReceived == 30000000`, `bytesTotal == null`, `localPath` ending in `abc.mp4.partial`

#### Scenario: Inspector returns null when no file exists

- **GIVEN** neither `${movieId}.mp4` nor `${movieId}.mp4.partial` exists for `movieId "unknown"`
- **WHEN** `inspectDownloadOnDisk(movieId: "unknown", downloadsDir: …)` is called
- **THEN** the result is `null`

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

### Requirement: DownloadRepository implementation selection via API_BASE_URL

The system SHALL select between the in-memory and HTTP implementations of `DownloadRepository` based on the compile-time constant `String.fromEnvironment('API_BASE_URL')`, mirroring the selection logic for `AuthRepository`, `ProfileManagementRepository`, and `CatalogRepository`.

The selection logic SHALL live in the Riverpod provider `downloadRepositoryProvider` (`lib/infrastructure/providers/download.repository_provider.dart`) and SHALL behave as follows:

```dart
const baseUrl = String.fromEnvironment('API_BASE_URL');
if (baseUrl.isEmpty) {
  return InMemoryDownloadRepository();  // existing behavior
}
return DioDownloadRepository(dio: ref.watch(dioProvider));  // new behavior
```

The selection SHALL happen at build time via the `--dart-define` mechanism — `String.fromEnvironment` is a `const` expression evaluated at compilation, NOT a runtime lookup of an environment variable.

When `API_BASE_URL` is unset (default), the provider SHALL return the existing `InMemoryDownloadRepository` so that:

- Developers running `flutter run` without the flag get the in-memory behavior identical to before this change (Big Buck Bunny from archive.org).
- Tests running `flutter test` (which never pass `--dart-define`) continue to use the in-memory implementation.

When `API_BASE_URL` is set to a non-empty string, the provider SHALL return a `DioDownloadRepository` consuming the centralized `dioProvider`.

The provider SHALL remain `@Riverpod(keepAlive: true)` so the chosen implementation is created once per app lifetime.

The selection SHALL be consistent with `authRepositoryProvider`, `profileManagementRepositoryProvider`, and `catalogRepositoryProvider`: a build either runs all repositories in in-memory mode (no flag) or all in HTTP mode (flag set). Mixed modes are not supported and SHALL not be exposed.

#### Scenario: Default build returns InMemoryDownloadRepository

- **GIVEN** the app is built without `--dart-define=API_BASE_URL`
- **WHEN** any consumer reads `downloadRepositoryProvider`
- **THEN** the returned instance is of runtime type `InMemoryDownloadRepository`

#### Scenario: Build with API_BASE_URL returns DioDownloadRepository

- **GIVEN** the app is built with `--dart-define=API_BASE_URL=http://localhost:8080`
- **WHEN** any consumer reads `downloadRepositoryProvider`
- **THEN** the returned instance is of runtime type `DioDownloadRepository`

#### Scenario: Test override remains supported

- **GIVEN** a test that overrides `downloadRepositoryProvider` with a fake implementation via `ProviderContainer.test`
- **WHEN** the consumer reads `downloadRepositoryProvider` in the test
- **THEN** the fake is returned regardless of the `API_BASE_URL` value the test was compiled with

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

### Requirement: DownloadKind enum

The system SHALL define an enum `DownloadKind` in
`lib/core/domain/model/download_kind.dart` (or co-located with the
existing download models) with exactly the following variants:

```dart
enum DownloadKind {
  cache,    // implicit, queued by the player at playback
  download, // explicit, the parent pressed "Télécharger"
}
```

`cache` is the default value for any download whose origin is the
implicit playback flow (the player started it under the hood).
`download` is set only by an explicit
`MarkAsDownloadUseCase.execute(...)` call (typically following the
"Télécharger" button + parent PIN challenge).

The semantic meaning:

- `cache`: this file is here for convenience but is **subject to
  auto-deletion** by `DownloadCleanupService`.
- `download`: this file is here **on purpose**, the parent wants it,
  do not auto-delete.

The enum SHALL serialize to/from JSON as the lowercase string
representation of the variant name (`"cache"` or `"download"`),
matching the manifest schema.

#### Scenario: Default kind for an implicit download

- **GIVEN** a movie play action triggers a fresh download via the player
- **WHEN** the download completes and the manifest entry is written
- **THEN** the entry's `kind` is `DownloadKind.cache`

#### Scenario: Explicit Télécharger sets download kind

- **GIVEN** a parent presses the `[Télécharger]` button on a movie
- **WHEN** `MarkAsDownloadUseCase.execute(...)` runs
- **THEN** the manifest entry's `kind` becomes `DownloadKind.download`

---

### Requirement: DownloadRepository.cacheMediaMetadata

The system SHALL expose a `cacheMediaMetadata` method on
`DownloadRepository`:

```dart
Future<void> cacheMediaMetadata({
  required String mediaId,
  required bool isEpisode,
  required String title,
  String? posterUrl,
  String? parentSeriesTitle,
});
```

The method SHALL persist `title`, `posterUrl`, and (for episodes)
`parentSeriesTitle` on the manifest entry for the given media.
Creates the entry with `kind == DownloadKind.cache` if absent. Other
existing fields (`kind`, `completedAt`, `lastPlayedAt`,
`triggeredByProfileId`) are preserved verbatim. Idempotent at value
level — a re-call with identical metadata SHALL NOT issue a manifest
write.

The method exists because `/catalog` filters items by **exact**
`age_category` of the active profile (per `API.md` § Catalogue). The
parent profile, opening the downloads manager, cannot resolve titles
of items targeting other age categories via the catalog. Persisting
title + poster at action time — when the caller (movie/series modal,
`[Télécharger]` button) holds the catalog object — bypasses the age
filter entirely. The manager UI prefers these cached fields over
`/catalog` lookups (cf. `download-management` spec).

#### Scenario: Caching from the modale stores title and poster

- **GIVEN** a movie modal renders with `Movie(id: "m-x", title: "Le Roi Lion", posterUrl: "https://…/roi.jpg")`
- **WHEN** the user taps `[Lire]` and the modale calls `cacheMediaMetadata(mediaId: "m-x", isEpisode: false, title: "Le Roi Lion", posterUrl: "https://…/roi.jpg")`
- **THEN** the manifest entry for `movies/m-x` exists with `cachedTitle == "Le Roi Lion"` and `cachedPosterUrl == "https://…/roi.jpg"`
- **AND** `kind` defaults to `DownloadKind.cache`

#### Scenario: Caching preserves existing manifest fields

- **GIVEN** `episodes/pingu-s01e04` is in the manifest with `kind == download`, `triggeredByProfileId == "marie"`, `lastPlayedAt == yesterday`
- **WHEN** `cacheMediaMetadata(mediaId: "pingu-s01e04", isEpisode: true, title: "Pingu skateur", parentSeriesTitle: "Pingu")` is called
- **THEN** the entry is updated with `cachedTitle == "Pingu skateur"` and `cachedParentSeriesTitle == "Pingu"`
- **AND** `kind`, `triggeredByProfileId`, and `lastPlayedAt` are unchanged

#### Scenario: Re-caching with identical values is a no-op

- **GIVEN** the manifest entry for `m-x` already has `cachedTitle == "Le Roi Lion"` and `cachedPosterUrl == "https://…/roi.jpg"`
- **WHEN** `cacheMediaMetadata` is called with identical title and posterUrl
- **THEN** no manifest write occurs

---

### Requirement: Download manifest sidecar persists applicative metadata

The system SHALL maintain a sidecar file
`${applicationDocumentsDirectory}/downloads/manifest.json` that holds
applicative metadata for each download present on disk. The file SHALL
be a JSON object whose keys are composite identifiers and whose values
are flat metadata objects:

```jsonc
{
  "movies/<id>": {
    "kind": "cache" | "download",
    "completedAt": "<ISO 8601 UTC>" | null,
    "lastPlayedAt": "<ISO 8601 UTC>" | null,
    "triggeredByProfileId": "<profile id>" | null,
    "cachedTitle": "<title captured at action time>" | null,
    "cachedPosterUrl": "<poster URL>" | null,
    "cachedParentSeriesTitle": "<series title, episodes only>" | null
  },
  "episodes/<id>": { ... same shape ... }
}
```

The `cachedTitle` / `cachedPosterUrl` / `cachedParentSeriesTitle` fields
are written by [DownloadRepository.cacheMediaMetadata] at action time
(player open, `[Télécharger]` button) and read by the manager UI as
the **primary** source of display metadata. They make the manager
robust to the strict age filter on `/catalog` (see that requirement).

The manifest SHALL be **dégradable**: its absence SHALL NOT prevent
any download flow from working. When the manifest does not exist or
is malformed, the system SHALL behave as if every entry were
`{kind: cache, completedAt: null, lastPlayedAt: <file.lastModified>,
triggeredByProfileId: null}`. A malformed manifest (JSON parse error)
SHALL emit a warning log and be treated as empty — the system SHALL
NOT crash and SHALL re-write a fresh empty manifest at the next
mutation.

The manifest SHALL be accessed exclusively through a
`DownloadManifestStore` infrastructure singleton in
`lib/infrastructure/downloads/manifest_store.dart`. This store SHALL:

1. Lazy-load the manifest into memory at first access.
2. Serialize all writes through a `synchronized.Lock` to prevent
   race conditions across concurrent download events.
3. Use **write-then-rename** atomicity for every persist operation:
   write a new `manifest.json.tmp`, then `File.rename` it to
   `manifest.json`. This ensures that a crash mid-write cannot
   leave a partially-written manifest on disk.

The `DownloadManifestStore` SHALL expose the following surface (used
by repositories and use cases):

```dart
abstract interface class DownloadManifestStore {
  Future<DownloadManifestEntry?> findFor({
    required String mediaId,
    required bool isEpisode,
  });
  Future<void> upsert({
    required String mediaId,
    required bool isEpisode,
    required DownloadManifestEntry entry,
  });
  Future<void> remove({
    required String mediaId,
    required bool isEpisode,
  });
  Future<List<({String key, DownloadManifestEntry entry})>> listAll();
}
```

The manifest SHALL NOT carry a schema version field at MVP. A
tolerant parser (ignore unknown keys) SHALL be used to keep room for
future extensions.

The manifest SHALL be removed (or its entry removed) when the
corresponding file is deleted via `deleteMovie/Episode`. After
deletion, the manifest SHALL NOT contain a stale entry.

#### Scenario: Fresh app start with no manifest

- **GIVEN** the app launches on a phone with no `manifest.json` and 3 existing `.mp4` files
- **WHEN** any consumer calls `listAll()` on the repository
- **THEN** all 3 entries are returned with `kind == cache`, `triggeredByProfileId == null`, `lastPlayedAt == file.lastModified`
- **AND** no exception is thrown

#### Scenario: Malformed manifest is recovered as empty

- **GIVEN** a `manifest.json` with the content `"this is not JSON"`
- **WHEN** the store is first accessed
- **THEN** a warning is logged
- **AND** the store behaves as if the manifest were empty
- **AND** the next mutation overwrites the file with valid JSON

#### Scenario: Atomic write survives crash mid-write

- **GIVEN** the store is mid-write (the `manifest.json.tmp` exists)
- **AND** the process crashes before the rename
- **WHEN** the app restarts
- **THEN** `manifest.json` still contains the previous valid content (the `.tmp` is orphaned and will be overwritten next time)

#### Scenario: Deletion removes manifest entry

- **GIVEN** `movies/abc` exists in the manifest with `kind == download`
- **WHEN** `deleteMovie("abc")` is called
- **THEN** the file is removed from disk
- **AND** the entry `movies/abc` is no longer present in the manifest

---

### Requirement: DownloadRepository.listAll enumerates all downloads

The Domain interface `DownloadRepository` SHALL expose:

```dart
Future<List<DownloadInventoryRecord>> listAll();
```

where `DownloadInventoryRecord` is a Domain value object:

```dart
class DownloadInventoryRecord {
  final String mediaId;
  final bool isEpisode;
  final int bytesOnDisk;
  final DownloadKind kind;
  final DateTime? completedAt;
  final DateTime? lastPlayedAt;
  final String? triggeredByProfileId;
}
```

`listAll` SHALL:

1. Scan `${applicationDocumentsDirectory}/downloads/movies/*.mp4` and
   `*.mp4.partial` ; same for `/downloads/episodes/`.
2. For each file, sum the `.mp4` and any matching `.partial` size to
   compute `bytesOnDisk`.
3. Look up the manifest entry by composite key (`movies/<id>` or
   `episodes/<id>`). If absent, fall back to `kind == cache`,
   `lastPlayedAt == file.lastModified`, others `null`.
4. Return the assembled list. Order is implementation-defined (the
   use case re-sorts for display).

`listAll` SHALL NOT issue any HTTP request. It is filesystem-only
and sub-100ms for typical inventories (~50 items).

`listAll` SHALL deduplicate: a media id with both a `.mp4` and a
`.partial` (e.g. partially-resumed) appears once with combined
`bytesOnDisk` and the manifest entry as-is.

#### Scenario: Empty disk returns empty list

- **GIVEN** `${documents}/downloads/` is empty (or absent)
- **WHEN** `listAll()` is called
- **THEN** the result is an empty list

#### Scenario: Mixed inventory with manifest hits and misses

- **GIVEN** `movies/abc.mp4` (100 MB) with manifest entry `kind: download`
- **AND** `episodes/pingu.mp4` (50 MB) without a manifest entry
- **WHEN** `listAll()` is called
- **THEN** the result has 2 records
- **AND** `abc` has `kind == download`
- **AND** `pingu` has `kind == cache` (default), `lastPlayedAt` set to file mtime

#### Scenario: Partial file contributes to bytesOnDisk

- **GIVEN** `movies/abc.mp4` (60 MB) and `movies/abc.mp4.partial` (15 MB)
- **WHEN** `listAll()` is called
- **THEN** the record for `abc` reports `bytesOnDisk == 78_643_200` (75 MB combined)

---

### Requirement: DownloadRepository.totalBytesOnDisk

The Domain interface `DownloadRepository` SHALL expose:

```dart
Future<int> totalBytesOnDisk();
```

`totalBytesOnDisk` SHALL return the sum of `bytesOnDisk` across all
records returned by `listAll()`. Implementations MAY compute it
directly via filesystem scan rather than consuming `listAll()`'s
result, as long as the value is consistent.

The method SHALL return `0` when no files exist or when the
downloads directory is absent. Never throws.

#### Scenario: Sum over downloads directory

- **GIVEN** files totaling 4_509_715_660 bytes in the downloads directory
- **WHEN** `totalBytesOnDisk()` is called
- **THEN** the result is `4_509_715_660`

#### Scenario: Zero on empty disk

- **GIVEN** an empty or absent downloads directory
- **WHEN** `totalBytesOnDisk()` is called
- **THEN** the result is `0`

---

### Requirement: DownloadRepository setMovieKind and setEpisodeKind

The Domain interface `DownloadRepository` SHALL expose:

```dart
Future<void> setMovieKind(String movieId, DownloadKind kind);
Future<void> setEpisodeKind(String episodeId, DownloadKind kind);
```

Each method SHALL:

1. Look up the manifest entry for the given id.
2. If absent, **create** an entry with the requested `kind`,
   `completedAt = null` (unless a `.mp4` exists, in which case use
   `file.lastModified`), `lastPlayedAt = file.lastModified` (or
   `null` if no file), `triggeredByProfileId = null`.
3. If present, **update** the `kind` field only — other fields
   (`completedAt`, `lastPlayedAt`, `triggeredByProfileId`) SHALL be
   preserved verbatim.
4. Persist the manifest atomically.

The methods SHALL be no-ops when the requested `kind` already
matches the current value: no manifest write, no error.

The methods SHALL be safe to call while a download is in-flight:
the manifest update happens out-of-band of the helper's stream and
does NOT inject any synchronization between the two — see design.md
D-8.

#### Scenario: Promote a cache item to download

- **GIVEN** `movies/abc` exists with `kind == cache`
- **WHEN** `setMovieKind("abc", DownloadKind.download)` is called
- **THEN** the manifest entry is updated to `kind == download`
- **AND** `lastPlayedAt`, `completedAt`, `triggeredByProfileId` are unchanged

#### Scenario: Set kind on an item with no manifest entry creates one

- **GIVEN** `movies/abc.mp4` exists on disk but no manifest entry
- **WHEN** `setMovieKind("abc", DownloadKind.download)` is called
- **THEN** a new manifest entry is created with `kind == download` and `lastPlayedAt == file.lastModified`

#### Scenario: Idempotent re-set is a no-op

- **GIVEN** `movies/abc` already has `kind == download`
- **WHEN** `setMovieKind("abc", DownloadKind.download)` is called
- **THEN** no manifest write occurs

---

### Requirement: DownloadRepository.markPlayed updates lastPlayedAt

The Domain interface `DownloadRepository` SHALL expose:

```dart
Future<void> markPlayed({
  required String mediaId,
  required bool isEpisode,
});
```

`markPlayed` SHALL:

1. Look up the manifest entry for the given id.
2. If absent, **create** an entry with `kind = cache`,
   `lastPlayedAt = DateTime.now()`, others `null`.
3. If present, update `lastPlayedAt = DateTime.now()`. Other fields
   are preserved.
4. Persist atomically.

`markPlayed` SHALL NOT bump `completedAt`, modify `kind`, or set
`triggeredByProfileId`.

`markPlayed` SHALL be called by `StartMoviePlaybackUseCase` and
`StartEpisodePlaybackUseCase` at the moment the player opens the
local file. The exact timing (open / first frame / dispose) is
implementation-defined ; the contract requires only that one call
per playback session occurs.

`markPlayed` SHALL be safe to call when no download exists for the
id (no `.mp4` on disk): the manifest entry is still created with
the timestamp. This handles the rare case where the player opens
a file that exists but has not yet been recorded.

#### Scenario: First playback creates a manifest entry

- **GIVEN** `movies/abc.mp4` exists on disk but no manifest entry
- **WHEN** `markPlayed(mediaId: "abc", isEpisode: false)` is called
- **THEN** a manifest entry is created with `kind == cache`, `lastPlayedAt == now`

#### Scenario: Repeat playback bumps lastPlayedAt only

- **GIVEN** `movies/abc` has manifest entry `kind: download, lastPlayedAt: yesterday`
- **WHEN** `markPlayed(mediaId: "abc", isEpisode: false)` is called
- **THEN** the entry has `kind == download` (preserved) and `lastPlayedAt == now`

---

### Requirement: kind getter on MovieDownload and EpisodeDownload snapshots

The system SHALL expose a getter `kind: DownloadKind` on both
`MovieDownload` and `EpisodeDownload` (the Domain value objects emitted
by `downloadMovie/Episode` streams). The value SHALL be hydrated by the
infrastructure helper from the manifest at the start of the streaming
session, and SHALL be carried verbatim on every subsequent snapshot for
that session.

If the manifest entry does not exist when the helper starts, the
getter SHALL return `DownloadKind.cache`.

The `kind` getter SHALL NOT participate in equality. Equality of
`MovieDownload` and `EpisodeDownload` remains based on
`(id, status, bytesReceived, updatedAt)` per the existing
requirement. A flip of `kind` mid-session SHALL NOT trigger a
re-emission on the stream.

A re-subscription to `downloadMovie/Episode` for the same id SHALL
re-read the manifest (so the new subscription sees the updated
`kind` if it was changed in the meantime).

#### Scenario: Snapshot carries kind from manifest

- **GIVEN** `movies/abc` is in the manifest with `kind == download`
- **WHEN** the player consumes `downloadMovie("abc")` and reads the first emitted snapshot
- **THEN** the snapshot's `kind` field is `DownloadKind.download`

#### Scenario: Mid-stream kind flip does not re-emit

- **GIVEN** an active subscription to `downloadMovie("abc")` showing `kind == cache`
- **WHEN** `setMovieKind("abc", DownloadKind.download)` is called from another part of the app
- **THEN** the active subscription does NOT receive a new event triggered solely by the kind change
- **AND** subsequent natural events (byte progress, status transition) carry the cached snapshot's original `kind == cache` (re-subscribe to see the new kind)

#### Scenario: Default kind when manifest is absent

- **GIVEN** no manifest entry exists for `movies/abc`
- **AND** a download for `abc` is initiated for the first time
- **WHEN** the first snapshot is emitted
- **THEN** the snapshot's `kind` is `DownloadKind.cache`

