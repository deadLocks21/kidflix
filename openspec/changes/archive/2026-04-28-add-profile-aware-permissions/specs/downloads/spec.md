## MODIFIED Requirements

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
