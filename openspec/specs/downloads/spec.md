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
`lib/core/domain/services/download.repository.dart` with the following
methods:

```dart
abstract interface class DownloadRepository {
  Future<MovieDownload?> findByMovieId(String movieId);

  Stream<MovieDownload> download(String movieId);

  Future<void> cancel(String movieId);

  Future<void> delete(String movieId);
}
```

Contract semantics:

- `findByMovieId` — returns the current state of the download for `movieId`,
  or `null` if no download has ever been initiated (never persisted, never
  cached). Returns a `MovieDownload` with `status == complete` if the file
  is fully downloaded on disk. A `status == downloading` or `readyToPlay`
  result indicates an in-flight download the caller can attach to via
  `download(movieId)`.
- `download` — initiates a new download or attaches to an in-flight one for
  `movieId`. Returns a broadcast-style stream: multiple listeners observing
  the same `movieId` simultaneously SHALL all receive the same events. The
  stream emits at least one event immediately (the current state) and
  further events on every meaningful status change. The stream completes
  when the download reaches `complete`, `failed`, or `cancelled`. Calling
  `download` on a `movieId` whose download is already `complete` SHALL emit
  a single `complete` event and close.
- `cancel` — cancels an in-flight download for `movieId`. No-op if the
  download is not active. Sets `status` to `cancelled` and closes the
  associated stream. Partial file is preserved for later resumption.
- `delete` — removes the local file(s) for `movieId` (both `.partial` and
  `.mp4` if present), cancels any in-flight download, and clears any cached
  state. Idempotent: safe to call when no download exists.

The repository SHALL NOT know about `Profile`, UI routing, `Movie`, or
playback concerns.

A future HTTP implementation SHALL map `download` to a streaming
`GET /download/:movieId` request with `Range` support for resumption,
preserving the Stream-of-snapshots contract.

#### Scenario: Idempotent delete

- **GIVEN** no download exists for `movieId "unknown"`
- **WHEN** `delete("unknown")` is called
- **THEN** the call completes successfully
- **AND** no exception is thrown

#### Scenario: Two listeners observe the same in-flight download

- **GIVEN** a download for `movieId "abc"` is at `readyToPlay`
- **WHEN** a second caller subscribes via `download("abc")`
- **THEN** the second caller immediately receives a `readyToPlay` event
- **AND** both callers receive every subsequent event in sync until completion

#### Scenario: Attaching to a completed download

- **GIVEN** `movieId "abc"` is already fully downloaded to disk
- **WHEN** `download("abc")` is called
- **THEN** the stream emits a single `complete` event
- **AND** the stream then closes

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

The `InMemoryDownloadRepository` SHALL be the offline / dev-mode implementation of `DownloadRepository`. It SHALL coexist with `DioDownloadRepository` (the HTTP-backed implementation), with selection at build time via `String.fromEnvironment('API_BASE_URL')` (see the *DownloadRepository implementation selection* requirement). It SHALL:

1. Use a **single hard-coded URL** for every `movieId` it downloads:
   `https://archive.org/download/BigBuckBunny_124/Content/big_buck_bunny_720p_surround.mp4`
   (defined as a `const` in the implementation file, documented as a
   stub for offline-mode and for the default `flutter run` developer experience). ~62 MB, MP4 H.264 720p ~10 min, supports
   `Accept-Ranges: bytes`. Archive.org issues a 302 redirect to a
   regional CDN — dio follows it automatically.
2. Perform the actual HTTP transfer by delegating to `streamHttpDownload(...)` (see the *Shared HTTP download streaming helper* requirement) with a privately-instantiated `Dio` instance (no `AuthInterceptor`, no `baseUrl`). The private `Dio` is a structural guarantee that no `Authorization: Bearer <jwt>` is ever sent to the third-party archive.org URL — the auth interceptor is bound to `dioProvider`, not to this private instance.
3. Compute `bytesTotal` via the helper from the `Content-Length` (or `Content-Range`) response header when present, null otherwise.
4. Respect the 2 MiB + 3% `readyToPlay` threshold, the 4 Hz progress
   throttling, and the `.partial` → `.mp4` rename on completion — all delegated to the helper.
5. Honor `Range` requests on resumption — delegated to the helper.
6. Keep in-process state (map `movieId → active download`) for dedup
   and cancellation. No persistence of this state across app restarts
   — `findByMovieId` reconstructs state by inspecting the filesystem on
   demand via `inspectDownloadOnDisk(...)`.

The HTTP implementation `DioDownloadRepository` (see the *HTTP implementation of DownloadRepository* requirement) SHALL share the same on-disk file layout (`${documents}/downloads/${movieId}.mp4` and `${movieId}.mp4.partial`), the same `MovieDownload` snapshot contract, and the same `cancel`/`delete` filesystem-only semantics. The contract (stream of `MovieDownload` snapshots, `.partial` → `.mp4` on disk, `findByMovieId` is filesystem-only) SHALL be preserved 1:1 across both implementations — they differ only in the URL the helper hits and in whether auth headers are injected by an interceptor.

#### Scenario: All movies download from the same URL

- **GIVEN** the in-memory repository
- **WHEN** `download("hp-ecole-des-sorciers")` is called
- **THEN** the HTTP request targets `https://archive.org/download/BigBuckBunny_124/Content/big_buck_bunny_720p_surround.mp4`

#### Scenario: Different movieIds produce different local files

- **WHEN** `download("abc")` and `download("xyz")` both complete
- **THEN** two distinct files exist on disk: `${documents}/downloads/abc.mp4` and `${documents}/downloads/xyz.mp4`
- **AND** both have identical bytes (same source URL)

#### Scenario: In-memory repository never sends auth headers to archive.org

- **GIVEN** a session is established (`currentSessionProvider` returns a non-null `Session`)
- **WHEN** `InMemoryDownloadRepository.download("abc")` is consumed
- **THEN** the outbound HTTP request to archive.org carries no `Authorization` header
- **AND** carries no `X-Device-Id` header

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

The system SHALL provide an HTTP implementation `DioDownloadRepository implements DownloadRepository` in `lib/infrastructure/downloads/dio.download.repository.dart` that calls the backend `GET /movies/{movie_id}/download` endpoint documented in `API.md` § Téléchargement de fichier vidéo.

The class SHALL accept a `Dio` instance via its constructor and SHALL NOT instantiate its own — the `Dio` is provided by `dioProvider`, which has the `AuthInterceptor` registered. The repository itself SHALL NOT add `Authorization`, `X-Device-Id`, or `X-Profile-Id` headers explicitly — these are injected transparently by the interceptor since `/movies/{movie_id}/download` does not start with `/auth/` and is not the `GET /profiles` bootstrap exemption.

```dart
DioDownloadRepository({required Dio dio, Directory? downloadsDirectory});
```

The optional `downloadsDirectory` SHALL be used only for tests; in production it falls back to `${applicationDocumentsDirectory}/downloads`. The class SHALL maintain an in-process map `Map<String, _ActiveDownload>` for dedup and cancellation, identical in shape and semantics to the in-memory implementation.

`download(String movieId)` SHALL:

1. If a download is already active for `movieId`, return the existing broadcast stream — no second HTTP request.
2. Otherwise, create a `StreamController<MovieDownload>.broadcast()` and a `CancelToken`, register the `_ActiveDownload`, and start a fire-and-forget call to `streamHttpDownload(...)` with:
   - `dio` = the constructor-injected `Dio` (with `AuthInterceptor`).
   - `url` = `'/movies/$movieId/download'` (relative path; resolves against `dio.options.baseUrl == $API_BASE_URL`).
   - `movieId`, `downloadsDir`, `cancelToken`, `isCancelled` = the active state.
3. Pipe every event from the helper into the controller and update the cached `currentSnapshot`. Close the controller when the helper closes.

`findByMovieId(String movieId)` SHALL:

1. Return the active in-process snapshot if a download is in flight for this `movieId`.
2. Otherwise, delegate to `inspectDownloadOnDisk(movieId, downloadsDir)` and return its result.
3. The repository SHALL NOT issue any HTTP request to determine `findByMovieId` — there is no documented `HEAD /movies/{movie_id}/download` or status endpoint, and the contract `findByMovieId` is filesystem-only.

`cancel(String movieId)` SHALL behave identically to the in-memory implementation: cancel the `CancelToken`, await the controller's close, preserve the `.partial`. No HTTP DELETE or cancel call to the backend.

`delete(String movieId)` SHALL behave identically to the in-memory implementation: cancel any active download, then remove both `${movieId}.mp4` and `${movieId}.mp4.partial` if they exist. No HTTP DELETE call to the backend.

The implementation SHALL NOT log raw response bodies, the `Authorization` header, the JWT, or the `X-Profile-Id` value at any log level.

The implementation SHALL NOT retry failed requests — retry policy is out of scope for this change.

The implementation SHALL NOT map HTTP error codes (401 / 403 / 404 / 5xx) to specific Domain exception types or specific `errorMessage` discriminators. Any non-2xx outcome is propagated by `streamHttpDownload` as `DownloadStatus.failed` with the dio-supplied error message verbatim. This includes the new `403 movie_above_age_category` code (introduced server-side by the `add-profile-permissions` backend change to enforce the age gate when a `:movie_id` exceeds the active profile's age category) — it is curl-only in practice (the homepage and search results never expose movies the profile cannot watch in HTTP mode), so the absence of a typed Domain exception is intentional. A future change MAY introduce typed sub-statuses (`unauthorized`, `forbidden`, `notFound`, `aboveAge`) if UI rendering requirements emerge.

#### Scenario: download() targets the relative path /movies/{id}/download

- **GIVEN** `dio.options.baseUrl == "http://localhost:8080"`
- **AND** the backend responds 200 with a 10 MB stream for `GET http://localhost:8080/movies/abc/download`
- **WHEN** `DioDownloadRepository.download("abc")` is consumed
- **THEN** the outbound HTTP request method is `GET` on path `/movies/abc/download` against `dio.options.baseUrl`
- **AND** the stream eventually emits `complete` with `localPath` ending in `abc.mp4`

#### Scenario: AuthInterceptor injects all three headers transparently

- **GIVEN** a session is established, a profile is selected, and `dioProvider` has the `AuthInterceptor` registered
- **WHEN** `download("abc")` is consumed
- **THEN** the outbound request to `/movies/abc/download` carries `Authorization: Bearer <jwt>`, `X-Device-Id: <device.id>`, and `X-Profile-Id: <profile.id>` headers
- **AND** the repository code does not reference these headers explicitly

#### Scenario: Concurrent download() calls for the same movieId share the stream

- **GIVEN** a download for `"abc"` is in flight
- **WHEN** `download("abc")` is called a second time before the first completes
- **THEN** no second HTTP request is initiated (verifiable via fake adapter request count)
- **AND** the second call returns a stream that receives the same events as the first

#### Scenario: findByMovieId after a fresh install returns null

- **GIVEN** the downloads directory is empty
- **AND** no download is in flight
- **WHEN** `findByMovieId("abc")` is called
- **THEN** the result is `null`
- **AND** no HTTP request is issued

#### Scenario: 4xx is surfaced as DownloadStatus.failed

- **GIVEN** the backend responds 403 with body `{"error": {"code": "movie_above_age_category"}}` on `GET /movies/abc/download`
- **WHEN** `download("abc")` is consumed
- **THEN** the stream emits a final event with `status == DownloadStatus.failed` and `errorMessage` non-null
- **AND** the stream closes
- **AND** no specific Domain exception is thrown

#### Scenario: cancel() preserves the .partial without backend call

- **GIVEN** a download for `"abc"` is in progress at 5 MB received
- **WHEN** `cancel("abc")` is called
- **THEN** no HTTP DELETE or cancel request is issued to the backend
- **AND** the in-flight GET is cancelled via the `CancelToken` (TCP close)
- **AND** a `cancelled` event is emitted with `localPath` ending in `abc.mp4.partial`
- **AND** the `.partial` file still exists on disk

#### Scenario: delete() removes local files without backend call

- **GIVEN** `${downloadsDir}/abc.mp4` exists
- **WHEN** `delete("abc")` is called
- **THEN** no HTTP DELETE is issued to the backend
- **AND** the file is removed from disk
- **AND** a subsequent `findByMovieId("abc")` returns `null`

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

