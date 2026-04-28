## Why

The `watch-progress` capability is the **last** `*Repository` still locked
to its in-memory implementation now that auth, profile-management,
catalog, and downloads each expose a Dio variant selectable via
`API_BASE_URL`. Because `InMemoryWatchProgressRepository` keeps progress
in a `Map` that is reset on every app restart, the resume-dialog flow
specified by `video-playback` (`Resume dialog offers two choices` —
`Reprendre à {position}` / `Recommencer`) only works **inside a single
session**: kill the app, relaunch, replay the same movie, and the
position is gone. The dialog never shows because `findFor` returns
`null`.

The contract for the three watch-progress endpoints is already frozen in
`API.md` § Progression de lecture (`GET /profiles/{pid}/progress/{mid}`,
`PUT /profiles/{pid}/progress/{mid}`, `GET /profiles/{pid}/progress`).
This change closes that loop by adding the HTTP variant, aligning
watch-progress with the same dual-implementation pattern the four other
capabilities already follow. The cross-restart resume behaviour falls
out for free — no `PlayerPage` change, no domain change, no usecase
change.

## What Changes

- Add `DioWatchProgressRepository`
  (`lib/infrastructure/watch_progress/dio.watch_progress.repository.dart`)
  implementing the existing `WatchProgressRepository` interface against
  the three endpoints documented in `API.md` § Progression de lecture.
  Consumes the shared `dioProvider` so `Authorization: Bearer <jwt>` and
  `X-Device-Id` are attached transparently by `AuthInterceptor`.
- Map `findFor` to `GET /profiles/{pid}/progress/{mid}` with `204 No
  Content` → `null`. A `200` response with a JSON body parses through a
  small `RemoteWatchProgressDto` and returns a `WatchProgress`.
- Map `save` to `PUT /profiles/{pid}/progress/{mid}` with the upsert
  body documented in `API.md` (`position_seconds`, `completed`,
  `updated_at`). Response body discarded — the contract is `Future<void>`.
- Map `listForProfile` to `GET /profiles/{pid}/progress` returning the
  `progress[]` array, parsed into `List<WatchProgress>` via the same
  DTO. Empty array → empty list.
- No metier-level Domain exception mapping. Any `4xx`/`5xx`/network
  error surfaces as a generic `DioException` (same posture as
  `DioCatalogRepository`). `API.md` documents no specific error code for
  these endpoints beyond the global `401 invalid_token` / `404 not_found`.
- Update `watchProgressRepository` provider
  (`lib/infrastructure/providers/watch_progress.repository_provider.dart`)
  to switch on `String.fromEnvironment('API_BASE_URL')`: empty →
  `InMemoryWatchProgressRepository`, non-empty → `DioWatchProgressRepository`
  consuming `dioProvider` — same shape as the four previous providers.
- Add `RemoteWatchProgressDto`
  (`lib/core/application/dtos/remote_watch_progress.dto.dart`) with
  `fromJson` + `toDomain` and a `toWireBody()` builder for the `PUT`
  request, mirroring the `RemoteProfileDto` / `RemoteMovieDto` shape.
- Extend the `PlayerPage` save policy: detect user seeks (position
  delta > 2 s between two consecutive `positionStream` events) and
  trigger an immediate out-of-band save, on top of the existing 10 s
  periodic timer + dispose + completion-at-90% triggers. Multi-device
  clients see scrubbed positions without waiting up to 10 s for the
  next tick.

## Capabilities

### New Capabilities

_None — no new capability is introduced. The HTTP variant lands inside
the existing `video-playback` capability, which currently owns the
`WatchProgressRepository` interface and the `InMemoryWatchProgressRepository`
mention._

### Modified Capabilities

- `video-playback`: relax the `WatchProgressRepository domain interface`
  requirement that names `InMemoryWatchProgressRepository` as the *sole*
  implementation; add a `DioWatchProgressRepository` requirement covering
  endpoint shape, header injection via the central `Dio`, the
  `204 → null` semantics on `findFor`, and the absence of metier-level
  error mapping; add a provider-selection requirement mirroring the four
  precedents. Modify the existing `Progress is saved periodically, on
  leave, and on completion` requirement to add a fourth save trigger:
  user seeks (position delta > 2 s between consecutive
  `positionStream` events). The Domain interface
  (`WatchProgressRepository`), `WatchProgress` model, application
  usecases (`GetWatchProgressUseCase`, `SaveWatchProgressUseCase`),
  resume dialog, and completion-at-90% logic are **unchanged**.

## Impact

- **Code touched**:
  - Added `lib/infrastructure/watch_progress/dio.watch_progress.repository.dart`
  - Added `lib/core/application/dtos/remote_watch_progress.dto.dart`
  - Modified `lib/infrastructure/providers/watch_progress.repository_provider.dart`
    (selects on `API_BASE_URL`)
  - Modified `lib/ui/pages/player/player.page.dart`
    (seek-save trigger added next to the existing periodic + dispose +
    completion saves)
  - Modified `lib/ui/pages/player/media_kit_player_engine.dart`
    (the resume position now travels via `Media.start` instead of a
    post-`open()` `seek()`; the previous code path was silently dropped
    on iOS — a latent bug only visible once HTTP persistence made the
    resume dialog fire across app restarts)
- **Tests**: existing `InMemoryWatchProgressRepository` tests stay green
  (contract preserved). Add `dio.watch_progress.repository_test.dart`
  covering the three endpoints (URL + method + body shape), the
  `204 → null` short-circuit, the empty-list response, and a `4xx`
  surfacing as a `DioException`. Add a `RemoteWatchProgressDto` test
  covering `fromJson`, `toDomain`, `toWireBody`, and round-trip.
- **API.md**: no edit — the three endpoints are already fully
  documented in § Progression de lecture; this change wires them up.
- **Dependencies**: none added; uses `dio` (already present).
- **Breaking changes**: none. The `WatchProgressRepository` interface,
  `WatchProgress` model, and the `Future<WatchProgress?>` /
  `Future<void>` / `Future<List<WatchProgress>>` signatures are
  byte-for-byte identical. Behaviour with `API_BASE_URL` empty is
  unchanged. The `PlayerPage` resume dialog and the catalog
  "Continuer à regarder" placeholder row are untouched.
- **Build/run**: same toggle as the four other Dio repositories —
  `flutter run --dart-define=API_BASE_URL=http://…` switches to HTTP
  mode globally. Cross-restart resume dialog now works against a real
  backend.
- **Out of scope** (deferred):
  - Wiring the catalog "Continuer à regarder" row to
    `listForProfile(profileId)`. The placeholder
    (`catalog_application.service.dart:131`) stays as-is. The
    `listForProfile` method ships in this change but has no production
    consumer yet.
  - "Vu" badge on movie cards for `completed: true` progresses. Will
    be revisited once the API exposes a richer per-card status.
