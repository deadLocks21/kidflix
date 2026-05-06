## ADDED Requirements

### Requirement: CatalogRepository.listCatalogForProfile

The system SHALL extend `CatalogRepository` with a profile-explicit
listing method:

```dart
Future<List<CatalogItem>> listCatalogForProfile(String profileId);
```

The method SHALL return the catalog items visible to the profile
identified by [profileId], regardless of which profile is currently
active in the session.

The method exists because `/catalog` returns ONLY items whose
`age_category` equals the active profile's exactly (per `API.md` §
Catalogue, not hierarchical). The downloads manager needs to surface
items downloaded by ANY family profile — querying the catalog once
per profile and unioning the results bridges that gap without backend
changes.

* The HTTP implementation SHALL issue `GET /catalog` with
  `X-Profile-Id: $profileId` pre-set on the per-call `Options.headers`.
  The `AuthInterceptor` SHALL preserve such an explicit override (see
  `kids-lock` / `auth` capability for that interceptor change).
* The in-memory implementation SHALL return the same content as
  `listCatalog()` (no profile filter at this layer).

#### Scenario: HTTP impl uses the per-call profile header

- **GIVEN** `currentProfileId` resolves to `"parent"` and the session contains a kid profile `"marie"`
- **WHEN** `listCatalogForProfile("marie")` is called
- **THEN** the outbound `GET /catalog` carries `X-Profile-Id: marie` (NOT `parent`)
- **AND** the response is parsed into the returned `List<CatalogItem>`

#### Scenario: In-memory impl ignores the profile id

- **GIVEN** the in-memory repo is in use
- **WHEN** `listCatalogForProfile("any-id")` is called
- **THEN** the result is identical to `listCatalog()`

---

### Requirement: AuthInterceptor preserves a per-call X-Profile-Id override

The system SHALL configure the `AuthInterceptor`
(`lib/infrastructure/http/auth.interceptor.dart`) to forward an
`X-Profile-Id` header that is already present on the outbound
request's `RequestOptions.headers` instead of overwriting it from
`currentProfileIdProvider`.

The behavior is unchanged when no `X-Profile-Id` header is set on the
per-call options — the interceptor still injects the active profile
id from the callback.

This carve-out enables `CatalogRepository.listCatalogForProfile` and
`SeriesRepository.findByIdForProfile` to address the backend on
behalf of an arbitrary family profile without rebuilding `Dio`.

#### Scenario: Interceptor preserves the explicit header

- **GIVEN** a `Dio` request whose `options.headers` already contains `'X-Profile-Id': 'marie'`
- **WHEN** the `AuthInterceptor.onRequest` callback fires
- **THEN** the outgoing request carries `X-Profile-Id: marie`
- **AND** the value is NOT replaced by `_currentProfileId()`

#### Scenario: Interceptor still injects when header is absent

- **GIVEN** a `Dio` request whose `options.headers` does NOT contain `X-Profile-Id`
- **AND** `_currentProfileId()` returns `"parent"`
- **WHEN** the interceptor fires
- **THEN** the outgoing request carries `X-Profile-Id: parent`

---

### Requirement: Movie detail modal exposes a Télécharger action

The system SHALL extend the movie detail modal (cf. requirement *Movie
detail modal is adaptive and presents full metadata*) to expose,
immediately to the right of the existing primary `[Lire]` button, a
secondary button whose label and behavior depend on the current `kind`
of the download for this movie:

| Current state | Button label | Tap behavior |
|---|---|---|
| No file on disk OR `kind == cache` | `[⬇ Télécharger]` | Triggers parent PIN gate (cf. *Download actions are gated by parent PIN when active profile is kid*), then `MarkAsDownloadUseCase.execute(mediaId, isEpisode: false)`. If no download is in flight, ALSO subscribes to `downloadMovie(id)` to start the actual transfer. |
| `kind == download`, file on disk | `[✓ Téléchargé]` (visually muted) | Opens a bottom sheet with `[Ne plus garder]` (calls `MarkAsCacheUseCase`) and `[Supprimer]` (calls `deleteMovie` after confirmation). Both options behind the PIN gate. |
| In-flight, not yet `complete` | `[⏸ X %]` (where X is `bytesReceived / bytesTotal`) | No tap action (or shows a tooltip "Téléchargement en cours"). |

The button SHALL reflect the current state reactively: a `Stream` /
`Future` consumer that observes `findForMovie(id)` (and `kind` via
the manifest) and rebuilds.

The button SHALL NOT replace or hide the `[Lire]` button. Both
remain visible side by side.

#### Scenario: Movie not yet downloaded shows Télécharger

- **GIVEN** the modal is open for a movie with no file on disk
- **THEN** the secondary button reads `[⬇ Télécharger]`

#### Scenario: Movie already downloaded shows Téléchargé

- **GIVEN** the modal is open for a movie whose manifest has `kind == download`
- **THEN** the secondary button reads `[✓ Téléchargé]`

#### Scenario: Tap on Télécharger triggers PIN gate then promotion

- **GIVEN** the active profile is a kid
- **AND** the modal is open for a movie not yet downloaded
- **WHEN** the user taps `[⬇ Télécharger]`
- **THEN** the parent PIN dialog appears
- **AND** on success, `MarkAsDownloadUseCase.execute` is invoked
- **AND** the actual download stream starts via `downloadMovie(id)` if not already in flight

#### Scenario: Mid-flight Télécharger flips manifest without restart

- **GIVEN** the modal is open and the movie is being downloaded as cache (player started it 30 s ago)
- **WHEN** the parent confirms the PIN and `MarkAsDownloadUseCase` runs
- **THEN** the manifest entry's `kind` becomes `download`
- **AND** the in-flight download continues without restart or interruption

---

### Requirement: Episode card and season section expose download actions

The system SHALL extend the series detail modal so that each episode
card (`episode_card.dart`) exposes a download icon affordance to the
right of the existing card content (title, duration, etc.):

| Current state | Icon | Tap behavior |
|---|---|---|
| No file OR `kind == cache` | `Icons.file_download_outlined` | PIN gate, then promote/start (`MarkAsDownloadUseCase` for the episode + subscribe to `downloadEpisode` if not in flight). |
| `kind == download` on disk | `Icons.file_download_done` | Opens action sheet `[Ne plus garder] / [Supprimer]`. |
| In flight | `Icons.file_download` with circular progress overlay (X %) | No tap. |

In the series detail modal, each season section
(`season_section.dart`) SHALL expose a header-level button
`[⬇ Télécharger la saison]` to the right of the season title. Its
behavior:

- If at least one episode of the season is **not** in `kind ==
  download` state (cache, in-flight, or absent), the button is
  enabled. Tapping it triggers the PIN gate, then
  `DownloadSeasonUseCase.execute(seriesId, seasonNumber)`. The button
  shows live progress (`"X / N épisodes"`) while the use case stream
  emits.
- If all episodes are already `kind == download`, the button reads
  `[✓ Saison téléchargée]` and is disabled (or transforms into a
  shortcut to delete the whole season — TBD, deferred).

The season-level button SHALL trigger the **single PIN gate** for
the whole season (one challenge, then all episodes). Per-episode
icon taps trigger their own gate.

The season-level button SHALL show a Snackbar
`"Saison Pingu — N épisodes téléchargés"` on completion.

If the user cancels the season download mid-flight (back button,
explicit cancel affordance — to be specified at impl time), the
in-flight episode download is cancelled (via `cancelEpisode`) and
the loop stops. Already-downloaded episodes remain `kind ==
download`.

#### Scenario: Episode icon shows Télécharger when absent

- **GIVEN** the series modal lists episode `pingu-s01e04` not yet on disk
- **THEN** the icon affordance is `Icons.file_download_outlined`

#### Scenario: Episode icon shows Done when downloaded

- **GIVEN** episode `pingu-s01e04` has manifest `kind == download`
- **THEN** the icon affordance is `Icons.file_download_done`

#### Scenario: Saison button uses single PIN gate

- **GIVEN** the active profile is a kid
- **AND** Season 1 has 8 episodes, none yet downloaded
- **WHEN** the user taps `[⬇ Télécharger la saison]`
- **THEN** the parent PIN dialog appears exactly once
- **AND** on success, episodes are downloaded sequentially without further PIN prompts
- **AND** each completed episode is automatically marked `kind == download`

#### Scenario: Saison button shows progress and Snackbar

- **GIVEN** Season 1 download starts, 5 episodes
- **WHEN** episode 3 completes
- **THEN** the season button label updates to `"Saison Pingu — 3 / 5 épisodes"`
- **WHEN** episode 5 completes (last)
- **THEN** the button transitions to `[✓ Saison téléchargée]`
- **AND** a Snackbar `"Saison Pingu — 5 épisodes téléchargés"` is displayed

#### Scenario: Saison cancellation stops loop, preserves done episodes

- **GIVEN** Season 1 download is at episode 3 of 8
- **AND** episodes 1 and 2 are already complete + marked `download`
- **WHEN** the user dismisses / cancels the season download
- **THEN** episode 3's in-flight download is cancelled (`cancelEpisode`)
- **AND** episodes 4–8 are NOT attempted
- **AND** episodes 1 and 2 remain `kind == download` on disk

---

### Requirement: Download actions are gated by parent PIN when active profile is kid

The system SHALL gate every action that mutates a download's `kind` to
`DownloadKind.download` or that initiates a `Télécharger la saison`
flow: when the active profile is **not** the main profile (parent),
the action MUST trigger the PIN challenge defined by the existing
`kids-lock` capability (requirement *Tapping the unlock button opens
a PIN dialog*).

The same dialog widget (`showUnlockPinDialog` or its sibling for
out-of-player contexts — implementation choice) SHALL be reused.
Implementations SHALL NOT define a parallel PIN dialog.

The challenge SHALL be invoked **before** the use case runs. On a
cancelled or invalid PIN, the use case SHALL NOT be called and the
UI state SHALL remain unchanged.

When the active profile **is** the main profile (parent), the
challenge SHALL be skipped and the use case SHALL run directly.

The PIN challenge SHALL also gate:

- The **Supprimer** action on a download (`deleteMovie/Episode`) —
  destructive, parent's authority.
- The **Ne plus garder** action (`MarkAsCacheUseCase`) — exposes
  the item to auto-cleanup, parent's authority.
- Navigation to the **Downloads page** (`/downloads`) — see the
  separate `download-management` requirement on this point.

The PIN challenge SHALL NOT gate:

- The implicit playback flow (pressing `[Lire]` on a movie or
  episode) — playback already triggers a `cache` download which
  remains under auto-cleanup, no parent intent needed.
- The `[Lire]` button on a tile in the Downloads page (the parent
  is already past the page-level gate).

#### Scenario: Kid profile cannot bypass the gate

- **GIVEN** the active profile is a kid
- **AND** the kid taps `[⬇ Télécharger]`
- **AND** the parent declines or wrong-PINs the dialog
- **THEN** `MarkAsDownloadUseCase` is NOT called
- **AND** the manifest is unchanged

#### Scenario: Parent profile skips the gate

- **GIVEN** the active profile is the main profile
- **AND** the parent taps `[⬇ Télécharger]`
- **THEN** the PIN dialog does NOT appear
- **AND** `MarkAsDownloadUseCase` is invoked directly

#### Scenario: Implicit cache download is not gated

- **GIVEN** the active profile is a kid
- **AND** the kid taps `[▶ Lire]` on a movie
- **THEN** the player opens normally and the underlying `downloadMovie` stream starts
- **AND** the PIN dialog does NOT appear
- **AND** the new manifest entry has `kind == cache` (no parent intent)
