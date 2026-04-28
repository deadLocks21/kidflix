## Why

The `downloads` capability is the last `*Repository` still locked to its
in-memory implementation now that auth, catalog, and profile-management
each expose a Dio variant selectable via `API_BASE_URL`. The
`InMemoryDownloadRepository` currently downloads from a hard-coded
archive.org URL — fine as a stub, but blocks consuming the documented
`GET /movies/{movie_id}/download` endpoint (cf. `API.md` § Téléchargement
de fichier vidéo) and prevents the player from streaming a real movie
once a backend is reachable. This change closes that loop and aligns
downloads with the same dual-implementation pattern the other three
capabilities already follow.

## What Changes

- Add `DioDownloadRepository` (`lib/infrastructure/downloads/dio.download.repository.dart`)
  hitting `GET /movies/{movie_id}/download`, consuming the shared
  `dioProvider` so `Authorization: Bearer <jwt>` and `X-Device-Id` are
  attached transparently by `AuthInterceptor`.
- Extract the streaming/throttling/`.partial`-rename logic shared by both
  repositories into a top-level helper `streamHttpDownload(...)` in
  `lib/infrastructure/downloads/http_download_stream.dart`. The helper
  takes the `Dio` instance and the URL (relative or absolute) and
  preserves the existing 2 MiB + 3 % `readyToPlay` threshold, the 4 Hz
  throttling, the `Range` resume on a `.partial`, and the
  `.partial` → `.mp4` rename on completion.
- Refactor `InMemoryDownloadRepository` to delegate its download loop to
  the same helper while keeping its private `Dio` (no `AuthInterceptor`,
  so credentials never leak to archive.org) and its hard-coded stub URL.
  Public behaviour and constructor signature unchanged.
- Update `downloadRepository` provider
  (`lib/infrastructure/providers/download.repository_provider.dart`) to
  switch on `String.fromEnvironment('API_BASE_URL')`: empty →
  `InMemoryDownloadRepository`, non-empty → `DioDownloadRepository`
  consuming `dioProvider` — same shape as `catalogRepository` /
  `authRepository` / `profileManagementRepository`.

## Capabilities

### New Capabilities

_None — no new capability is introduced. The HTTP variant lands inside the existing `downloads` capability._

### Modified Capabilities

- `downloads`: drop the requirement that names `InMemoryDownloadRepository`
  as the *sole* implementation; describe the shared helper contract; add
  a `DioDownloadRepository` requirement covering endpoint shape, header
  injection via the central `Dio`, error mapping, and the absence of
  backend `cancel`/`delete` calls. The Domain interface
  (`DownloadRepository`), `MovieDownload` model, file-layout, threshold,
  throttling, resume, cancel, and delete requirements are unchanged.

## Impact

- **Code touched**:
  - Added `lib/infrastructure/downloads/dio.download.repository.dart`
  - Added `lib/infrastructure/downloads/http_download_stream.dart` (helper)
  - Modified `lib/infrastructure/downloads/in_memory.download.repository.dart`
    (delegates to the helper; no contract change)
  - Modified `lib/infrastructure/providers/download.repository_provider.dart`
    (selects on `API_BASE_URL`)
- **Tests**: existing `InMemoryDownloadRepository` tests stay green
  (contract preserved); add a `DioDownloadRepository` test covering
  endpoint URL, header injection delegation, range resume, and a 4xx →
  `failed` mapping. Helper unit tests if there are paths not exercised
  through the two repos.
- **API.md**: no edit — `GET /movies/{movie_id}/download` is already
  documented; this change wires it up.
- **Dependencies**: none added; uses `dio` and `path_provider`
  (already present).
- **Breaking changes**: none. The `DownloadRepository` interface,
  `MovieDownload` snapshots, and the on-disk layout are byte-for-byte
  identical. Behaviour with `API_BASE_URL` empty is unchanged.
- **Build/run**: same toggle as the other three Dio repositories —
  `flutter run --dart-define=API_BASE_URL=http://…` switches to HTTP
  mode globally.
