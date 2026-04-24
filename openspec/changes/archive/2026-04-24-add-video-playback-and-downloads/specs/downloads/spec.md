# Downloads

Téléchargement d'un film vers le stockage local de l'appareil, pour permettre
la lecture hors-ligne une fois complet et la lecture immédiate sur fichier
partiel tant que le download est en cours. Couvre le modèle Domain d'un
téléchargement, le contrat repository, l'implémentation in-memory réelle
(HTTP via `dio`, FS via `path_provider`), le suivi du statut en stream, la
gestion du fichier partiel avec renommage final, le seuil de début de
lecture, l'annulation, la reprise (Range request), et la suppression. Ne
couvre PAS la queue de téléchargements multi-films, les téléchargements en
arrière-plan OS-level, les notifications système, la reprise automatique
après crash de l'app, ni la gestion du stockage (purge, quotas).

## ADDED Requirements

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

For this change, the `InMemoryDownloadRepository` SHALL be the sole
implementation of `DownloadRepository`. It SHALL:

1. Use a **single hard-coded URL** for every `movieId` it downloads:
   `https://archive.org/download/BigBuckBunny_124/Content/big_buck_bunny_720p_surround.mp4`
   (defined as a `const` in the implementation file, documented as a
   stub for MVP). ~62 MB, MP4 H.264 720p ~10 min, supports
   `Accept-Ranges: bytes`. Archive.org issues a 302 redirect to a
   regional CDN — dio follows it automatically.
2. Perform the actual HTTP transfer using `dio` with streaming response
   mode, writing bytes to `${documents}/downloads/${movieId}.mp4.partial`
   as they arrive.
3. Compute `bytesTotal` from the `Content-Length` response header when
   present, null otherwise.
4. Respect the 2 MiB + 3% `readyToPlay` threshold, the 4 Hz progress
   throttling, and the `.partial` → `.mp4` rename on completion.
5. Honor `Range` requests on resumption.
6. Keep in-process state (map `movieId → active download`) for dedup
   and cancellation. No persistence of this state across app restarts
   — `findByMovieId` reconstructs state by inspecting the filesystem on
   demand.

A future HTTP implementation SHALL replace this class by a
`BackendDownloadRepository` that maps `download(movieId)` to a
`GET /download/:movieId` on the Kidflix backend. The contract (stream
of `MovieDownload` snapshots, `.partial` → `.mp4` on disk) SHALL be
preserved 1:1.

#### Scenario: All movies download from the same URL

- **GIVEN** the in-memory repository
- **WHEN** `download("hp-ecole-des-sorciers")` is called
- **THEN** the HTTP request targets `https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4`

#### Scenario: Different movieIds produce different local files

- **WHEN** `download("abc")` and `download("xyz")` both complete
- **THEN** two distinct files exist on disk: `${documents}/downloads/abc.mp4` and `${documents}/downloads/xyz.mp4`
- **AND** both have identical bytes (same source URL)
