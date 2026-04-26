# video-playback Specification

## Purpose
TBD - created by archiving change add-video-playback-and-downloads. Update Purpose after archive.
## Requirements
### Requirement: WatchProgress domain model

The system SHALL represent a watch progress as an immutable Domain value
object `WatchProgress` with the following fields:

- `profileId`: stable identifier of the profile this progress belongs to
  (string, equals `Profile.id`).
- `movieId`: stable identifier of the movie (string, equals `Movie.id`).
- `positionSeconds`: integer number of seconds from the start of the
  movie (`>= 0`).
- `completed`: boolean flag indicating the movie has been watched past
  the completion threshold (see completion threshold requirement).
- `updatedAt`: `DateTime` of the last save.

The entity SHALL be equatable by the pair `(profileId, movieId)` — two
`WatchProgress` instances for the same profile/movie are considered
identical for lookup purposes, regardless of position or timestamp. The
most recent `updatedAt` wins when multiple writes race.

The model SHALL NOT include `deviceId`. Multi-device identity is a
server-side concern introduced by the future HTTP implementation; the
client contract is unchanged.

#### Scenario: Equality by profile and movie

- **GIVEN** two `WatchProgress` instances with the same `profileId` and `movieId` but different `positionSeconds`
- **THEN** `a == b` is true
- **AND** they are treated as the same progress for lookup

#### Scenario: Valid zero-position progress

- **GIVEN** a `WatchProgress` with `positionSeconds = 0` and `completed = false`
- **THEN** the value is valid and represents "never watched past the start"

---

### Requirement: WatchProgressRepository domain interface

The system SHALL define a Domain interface `WatchProgressRepository` in
`lib/core/domain/services/watch_progress.repository.dart` with the
following methods:

```dart
abstract interface class WatchProgressRepository {
  Future<WatchProgress?> findFor({
    required String profileId,
    required String movieId,
  });

  Future<void> save(WatchProgress progress);

  Future<List<WatchProgress>> listForProfile(String profileId);
}
```

Contract semantics:

- `findFor` — returns the current `WatchProgress` for the given
  `(profileId, movieId)`, or `null` if none exists. Never throws on
  missing data.
- `save` — upserts the progress. If a `WatchProgress` already exists
  for the same `(profileId, movieId)`, it is replaced. If not, it is
  inserted. The `updatedAt` of the passed instance is stored verbatim.
- `listForProfile` — returns all progresses recorded for `profileId`,
  in implementation-defined order. Used by future capabilities
  (e.g., a real `continueWatching` row). Returns an empty list when
  no progresses exist.

The repository SHALL NOT know about UI, routes, `Movie` internals, or
download concerns.

For this change, the repository SHALL be implemented as
`InMemoryWatchProgressRepository` storing a `Map<(profileId, movieId), WatchProgress>`
in RAM. Entries are lost at app restart — acceptable for MVP. A future
HTTP implementation SHALL map `save` to `POST /progress/:movieId`,
`findFor` to `GET /progress/:movieId`, and `listForProfile` to
`GET /progress`, preserving the contract.

#### Scenario: Save then findFor returns the saved progress

- **GIVEN** no progress exists for `(profile "p1", movie "abc")`
- **WHEN** `save(WatchProgress(profileId: "p1", movieId: "abc", positionSeconds: 300, completed: false, updatedAt: t1))` is called
- **AND** `findFor(profileId: "p1", movieId: "abc")` is called
- **THEN** the returned `WatchProgress` has `positionSeconds == 300` and `completed == false`

#### Scenario: Second save overwrites the first

- **GIVEN** an existing progress for `(p1, abc)` with `positionSeconds = 300`
- **WHEN** `save(WatchProgress(..., positionSeconds: 600, ...))` is called for the same `(p1, abc)`
- **AND** `findFor(profileId: "p1", movieId: "abc")` is called
- **THEN** the returned `WatchProgress` has `positionSeconds == 600`

#### Scenario: findFor returns null for unknown pair

- **GIVEN** no progress exists for `(p1, xyz)`
- **WHEN** `findFor(profileId: "p1", movieId: "xyz")` is called
- **THEN** the result is `null`

#### Scenario: listForProfile returns only that profile's entries

- **GIVEN** progresses saved for `(p1, abc)`, `(p1, def)`, `(p2, abc)`
- **WHEN** `listForProfile("p1")` is called
- **THEN** the result contains exactly the progresses for `(p1, abc)` and `(p1, def)`
- **AND** does NOT contain `(p2, abc)`

---

### Requirement: Play button in the movie detail modal navigates to the player page

The `MovieDetailModal` (rendered by `showMovieDetailModal`) SHALL render
its "Lire" primary button in the **enabled** Material state. Tapping the
button SHALL:

1. Dismiss the modal.
2. Navigate to the route `/player/:movieId` where `:movieId` is the
   `id` of the movie represented by the modal.

The previous requirement from the `catalog` capability ("Play button is
visible but disabled in MVP") is REMOVED by this change — see the
`catalog` capability delta in this same change.

#### Scenario: Tapping Lire opens the player page

- **GIVEN** the detail modal is open for a movie with `id = "totoro"`
- **WHEN** the user taps the `"Lire"` button
- **THEN** the modal dismisses
- **AND** the router navigates to `/player/totoro`

#### Scenario: Play button is not disabled

- **GIVEN** the detail modal is open for any movie
- **WHEN** the button is rendered
- **THEN** its `onPressed` callback is non-null
- **AND** it is not displayed in the Material disabled state

---

### Requirement: Player route is /player/:movieId

The router SHALL expose a new route `/player/:movieId` rendering the
`PlayerPage`. The `movieId` path parameter is required and cannot be
null or empty.

The route SHALL be defined as a constant in `AppRoutes`:
`AppRoutes.player = '/player/:movieId'`.

Navigating to the route SHALL be authorized only when a profile is
selected (the `ProfileSelected` session state). If the session is not
in this state (e.g., the user got there via a deep link without a
selected profile), the existing router redirect behavior SHALL apply
and the user is routed to the appropriate screen per the session state.

#### Scenario: Deep link to player with selected profile

- **GIVEN** the session state is `ProfileSelected` for a profile with `ageCategory == AgeCategory.enfant`
- **AND** a movie with `id = "totoro"` exists in the catalog for that age category
- **WHEN** the router navigates to `/player/totoro`
- **THEN** the `PlayerPage` is rendered for `movieId = "totoro"`

#### Scenario: Navigation without selected profile redirects

- **GIVEN** the session state is `Anonymous`
- **WHEN** the router receives a navigation to `/player/totoro`
- **THEN** the existing session-state redirect guards apply
- **AND** the user is redirected to `/phone`

---

### Requirement: Player page orchestrates download-then-play

The `PlayerPage` SHALL, on mount:

1. Read the active profile from the session controller.
2. Call `findByMovieId(movieId)` on the `DownloadRepository`:
   - If the result has `status == complete`: skip directly to step 4
     with `localPath` as the source.
   - Otherwise (null, `downloading`, `readyToPlay`, `failed`,
     `cancelled`): proceed to step 3.
3. Subscribe to `DownloadRepository.download(movieId)`:
   - While events are `downloading`: render the download gate
     (progress bar + bytes received / total + cancel button).
   - On the first `readyToPlay` event: transition to step 4 using
     `event.localPath` as the source.
   - On `failed` or `cancelled`: render the error state (see error
     state requirement) and stay there until the user acts.
4. Resolve the initial playback position:
   - Call `GetWatchProgressUseCase.execute(profileId, movieId)`.
   - If the returned `WatchProgressDto` is null, OR
     `positionSeconds < 10`, OR `completed == true`: the initial
     position is 0 seconds (no dialog).
   - Otherwise: show the resume dialog (see resume dialog
     requirement). The dialog's chosen action determines the initial
     position (either the stored `positionSeconds`, or 0).
5. Instantiate a `media_kit` `Player` and `VideoController`, open the
   `localPath` as `file://${localPath}`, seek to the initial position
   (if > 0), then call `play()`.

The transition from step 3 to step 4 MUST happen without tearing down
the page. The download stream MUST continue to be observed in the
background while the player plays, so the UI can reflect ongoing
download progress on the seek bar (buffered indicator) and detect
`complete` to update the source path if needed.

If `complete` is emitted after `readyToPlay` and the `localPath`
switches from `.partial` to `.mp4`, the `PlayerPage` SHALL NOT
re-open the media in `media_kit` — the already-opened file descriptor
remains valid (POSIX inode semantics). Platform-specific exceptions
(Windows) are handled as documented in `design.md`.

#### Scenario: Already-downloaded movie plays immediately

- **GIVEN** `findByMovieId("totoro")` returns `status == complete` with a valid `localPath`
- **WHEN** the `PlayerPage` mounts for `movieId = "totoro"`
- **THEN** the download gate is NOT shown
- **AND** the resume-dialog check proceeds immediately
- **AND** the player opens the local file

#### Scenario: Fresh download shows gate then transitions to player

- **GIVEN** no prior download for `"totoro"` exists
- **WHEN** the `PlayerPage` mounts for `movieId = "totoro"`
- **THEN** the download gate is shown first with a progress bar
- **AND** when the download emits `readyToPlay`, the gate is replaced by the player surface
- **AND** the player starts playing the `.partial` file

---

### Requirement: Download gate UI shows progress and cancel affordance

The `PlayerPage` SHALL render a **download gate** occupying the full
player surface while the download for the current `movieId` is in
`downloading` status (has not yet reached `readyToPlay`), containing:

- The `Movie.title` as a header.
- A determinate `LinearProgressIndicator` when `bytesTotal` is non-null,
  fed by `bytesReceived / bytesTotal`. An indeterminate
  `CircularProgressIndicator` when `bytesTotal` is null.
- A caption line: `"{formattedReceived} / {formattedTotal}"` when
  total is known (e.g., `"12.3 MB / 158 MB"`), else
  `"{formattedReceived}"` alone. Formatting rounds to 1 decimal place
  in MB.
- A secondary "Annuler" button that triggers
  `CancelMovieDownloadUseCase.execute(movieId)` and pops the route.

The gate SHALL NOT show any video surface. The download gate is the
only thing on screen until `readyToPlay` is reached.

#### Scenario: Gate displays progress on a known-size download

- **GIVEN** a download emits `downloading` with `bytesReceived = 12_300_000` and `bytesTotal = 158_000_000`
- **WHEN** the download gate is rendered
- **THEN** the progress indicator shows ~7.8%
- **AND** the caption reads `"12.3 MB / 158.0 MB"` (or equivalent rounding)

#### Scenario: Cancel button cancels download and exits

- **GIVEN** the download gate is visible for `"totoro"`
- **WHEN** the user taps `"Annuler"`
- **THEN** `CancelMovieDownloadUseCase.execute("totoro")` is invoked
- **AND** the `PlayerPage` is popped (returns to the home)

---

### Requirement: Resume dialog offers two choices

The `PlayerPage` SHALL present a modal dialog **before** opening the
`media_kit` player when a non-trivial prior progress exists for
`(profileId, movieId)` (i.e., `positionSeconds >= 10` AND
`completed == false`), containing:

- Title: `"Reprendre la lecture ?"`.
- Primary action: `"Reprendre à {formattedPosition}"` where
  `formattedPosition` is the position formatted as `"Xh YY"` or
  `"XX min"` using the existing `formatDurationHuman` helper
  (`lib/shared/duration_format.dart`).
- Secondary action: `"Recommencer"`.

Tapping the primary action SHALL pass the stored `positionSeconds` as
the initial playback position. Tapping the secondary action SHALL pass
`0` as the initial playback position (but does NOT delete the stored
progress — future saves will overwrite it).

The dialog SHALL be non-dismissible by tapping outside or pressing
back/escape — the user MUST explicitly choose one of the two actions.
If the user exits the player before making a choice (e.g., via the
home button on mobile), the page SHALL be popped without opening the
player.

#### Scenario: Dialog shown for 30-minute progress

- **GIVEN** a stored progress for `(p1, totoro)` with `positionSeconds = 1800` and `completed = false`
- **WHEN** the `PlayerPage` mounts for that movie
- **THEN** a dialog is shown with title `"Reprendre la lecture ?"`
- **AND** the primary action reads `"Reprendre à 30 min"`
- **AND** the secondary action reads `"Recommencer"`

#### Scenario: Reprendre seeks to stored position

- **GIVEN** the resume dialog is shown for `positionSeconds = 1800`
- **WHEN** the user taps `"Reprendre à 30 min"`
- **THEN** the player opens the media and seeks to 1800 seconds before calling `play()`

#### Scenario: Recommencer starts from zero

- **GIVEN** the resume dialog is shown
- **WHEN** the user taps `"Recommencer"`
- **THEN** the player opens the media at position 0 and calls `play()`
- **AND** the stored progress is NOT deleted

#### Scenario: No dialog for short progress

- **GIVEN** a stored progress with `positionSeconds = 4`
- **WHEN** the `PlayerPage` mounts
- **THEN** no dialog is shown
- **AND** the player starts at position 0

#### Scenario: No dialog for completed movie

- **GIVEN** a stored progress with `completed = true`
- **WHEN** the `PlayerPage` mounts
- **THEN** no dialog is shown
- **AND** the player starts at position 0

---

### Requirement: Player UI uses MaterialVideoControls with a custom top bar

The `PlayerPage` SHALL render the `Video` widget from `media_kit_video`
with its default `AdaptiveVideoControls` / `MaterialVideoControls`
overlay — the player UI is NOT hand-rolled. The page SHALL configure
the overlay through a `MaterialVideoControlsTheme` whose contents
depend on the player's local lock state (`_isLocked`).

**When `_isLocked == false` (unlocked, default state) :**

- The **top button bar** SHALL contain, in order:
  1. An `IconButton` with `Icons.close` that invokes the page's close
     handler (restores mobile system UI, triggers a final progress
     save via `dispose`, then navigates back to `/home`).
  2. A single-line, ellipsis-truncated `Text` of the movie title.
- The **bottom button bar** SHALL contain, in order:
  `MaterialPlayOrPauseButton`, `MaterialPositionIndicator`, a `Spacer`,
  `MaterialFullscreenButton`, and a **lock toggle button** rendering
  `Icons.lock_outline`. Tapping the lock button engages the kids-lock
  (see capability `kids-lock` for the engagement semantics).
- `displaySeekBar` SHALL be `true`.
- `seekGesture`, `volumeGesture`, `brightnessGesture` SHALL be enabled
  (default `true`).
- `speedUpOnLongPress` SHALL be disabled.
- `seekOnDoubleTap` SHALL be disabled.
- `visibleOnMount` SHALL be `true` (controls appear on player open,
  auto-hide after `controlsHoverDuration`, reappear on tap/hover —
  behavior owned by `MaterialVideoControls`).
- No other buttons (volume, captions / subtitles, skip previous/next,
  rewind / fast-forward) SHALL be present in the button bars.

**When `_isLocked == true` (locked state, see capability `kids-lock`) :**

- The **top button bar** SHALL contain only the movie title (close button removed).
- The **primary button bar** SHALL be empty (`const []`).
- The **bottom button bar** SHALL contain, in order: `MaterialPlayOrPauseButton`, `MaterialPositionIndicator`, a `Spacer`, `MaterialFullscreenButton`, and an unlock button rendering `Icons.lock` (closed padlock). The desktop variant inserts `MaterialDesktopVolumeButton` between play and position indicator.
- `displaySeekBar` SHALL be `false` — the seek bar is hidden so the kid cannot scrub through the movie.
- `seekGesture` SHALL be disabled — no swipe-to-seek.
- `seekOnDoubleTap` and `speedUpOnLongPress` SHALL remain disabled.
- `volumeGesture` and `brightnessGesture` SHALL remain enabled — volume and brightness adjustments are kid-safe and improve comfort.
- `visibleOnMount`, `controlsHoverDuration`, and the tap-to-toggle visibility behavior SHALL remain unchanged — locked-state controls appear on tap and auto-hide exactly like the unlocked controls.

The same theme structure SHALL apply to the desktop variant
(`MaterialDesktopVideoControlsThemeData`) with the corresponding
`MaterialDesktop*` button widgets.

Seek-past-buffered is **not** clamped by the page — `mpv` (via
`media_kit`) stalls automatically when asked to read bytes not yet
present in the growing local file, and resumes once the download
catches up. The user experience is a brief buffering indicator, not a
hard error. (Unchanged.)

#### Scenario: Top bar shows close button and title (unlocked)

- **GIVEN** playback has started for a movie with title `"Totoro"`
- **AND** the player is unlocked
- **THEN** the top button bar shows an `Icons.close` IconButton
- **AND** the top button bar shows the text `"Totoro"` (truncated with ellipsis if longer than the available width)

#### Scenario: Bottom bar contains a lock button (unlocked)

- **GIVEN** the player is unlocked
- **WHEN** the user taps the video to reveal controls
- **THEN** the bottom button bar contains, after
  `MaterialFullscreenButton`, a button rendering `Icons.lock_outline`
  with tooltip `"Verrouiller"`

#### Scenario: Close button triggers progress save and navigation

- **GIVEN** the user has been watching for 2 minutes
- **AND** the player is unlocked
- **WHEN** the user taps the top-bar close button
- **THEN** `SaveWatchProgressUseCase.execute` is called with `positionSeconds ≈ 120`
- **AND** the router navigates to `/home`

#### Scenario: Shortcut gestures are disabled (unlocked)

- **GIVEN** the player is active and unlocked
- **WHEN** the user long-presses on the video surface
- **THEN** playback speed does NOT increase
- **WHEN** the user double-taps on the left or right half of the video
- **THEN** playback does NOT skip backward or forward

#### Scenario: Seek beyond buffered region stalls, does not crash

- **GIVEN** the video is playing with only 30% of the file downloaded
- **AND** the player is unlocked
- **WHEN** the user drags the seek bar to 80% of duration
- **THEN** `media_kit` attempts the seek
- **AND** playback briefly stalls (mpv shows its buffering indicator)
- **AND** playback resumes automatically when the download reaches the requested offset
- **AND** no exception is thrown by the `PlayerPage`

#### Scenario: Top bar keeps title but drops close button when locked

- **GIVEN** the player is locked and the movie title is `"Totoro"`
- **WHEN** the user taps the video to reveal controls
- **THEN** the top button bar shows the text `"Totoro"`
- **AND** no Close button is rendered
- **AND** no seek bar is rendered

#### Scenario: Bottom bar keeps comfort controls + unlock when locked

- **GIVEN** the player is locked
- **WHEN** the user taps the video to reveal controls
- **THEN** the mobile bottom button bar shows `[MaterialPlayOrPauseButton, MaterialPositionIndicator, Spacer, MaterialFullscreenButton, UnlockButton]`
- **AND** the lock button (open padlock) is NOT present

#### Scenario: Seek gestures disabled but volume/brightness kept when locked

- **GIVEN** the player is locked
- **WHEN** the user swipes horizontally on the video surface
- **THEN** no seek occurs
- **WHEN** the user double-taps the video
- **THEN** no skip occurs
- **WHEN** the user swipes vertically on the right half
- **THEN** the volume changes
- **WHEN** the user swipes vertically on the left half
- **THEN** the brightness changes

### Requirement: Progress is saved periodically, on leave, and on completion

While the video is **playing** (not paused), the `PlayerPage` SHALL
invoke `SaveWatchProgressUseCase.execute` every **10 seconds** of
playback wall-clock time, passing the current `positionSeconds`,
`completed = false` (unless the completion threshold has been crossed
— see next requirement), and `updatedAt = now`.

The periodic timer SHALL:

- Start when playback begins.
- Pause when playback is paused.
- Resume when playback resumes.
- Stop when the page is disposed.

On page dispose (user taps close, navigates back, or the route is
popped for any reason), the `PlayerPage` SHALL synchronously save the
**final** progress before disposing the `media_kit` player, passing
the last known `positionSeconds` and the current `completed` flag.

#### Scenario: Periodic save while playing

- **GIVEN** the video has been playing for 22 seconds without interaction
- **WHEN** the timer ticks
- **THEN** `SaveWatchProgressUseCase.execute` has been called twice (at t=10s and t=20s)
- **AND** the last call carries `positionSeconds == 20`

#### Scenario: No save while paused

- **GIVEN** the video is paused at position 45 seconds
- **WHEN** 30 seconds of wall-clock time elapse with the video still paused
- **THEN** no additional `save` call is made beyond whatever was scheduled before the pause

#### Scenario: Final save on dispose

- **GIVEN** the user has been watching for 147 seconds
- **WHEN** the user taps the close button
- **THEN** `SaveWatchProgressUseCase.execute` is called one final time with `positionSeconds == 147`
- **AND** the player is then disposed

---

### Requirement: Movie is marked completed past 90% watched

The `PlayerPage` SHALL invoke `SaveWatchProgressUseCase.execute`
**once** with `completed = true` when playback reaches a position such
that `positionSeconds / durationSeconds > 0.9`. This completion save is
in addition to the periodic 10-second saves.

Once `completed = true` has been saved for the current playback
session, the flag SHALL NOT be reset to `false` within the same
session, even if the user seeks backward below the threshold.

At the next session for the same `(profileId, movieId)`, the
`PlayerPage` SHALL see the `completed = true` stored progress and
SHALL NOT show the resume dialog (per the resume dialog requirement).

#### Scenario: Completion triggered at 91%

- **GIVEN** the movie duration is 600 seconds
- **WHEN** playback reaches position 546 seconds (91%)
- **THEN** `SaveWatchProgressUseCase.execute` is called with `completed == true` and `positionSeconds == 546`

#### Scenario: Completion not reset on seek-back

- **GIVEN** the video has just been marked completed at position 546 seconds
- **WHEN** the user seeks back to position 100 seconds
- **AND** a periodic save fires at position 110 seconds
- **THEN** the saved progress still has `completed == true` (not reset to false)

---

### Requirement: Error and cancelled states offer a clear recovery

The `PlayerPage` SHALL render an error state if the download emits
`failed` (with `errorMessage`) or `cancelled` **before** `readyToPlay`
has been reached, containing:

- An error message:
  - For `failed`: `"Impossible de télécharger le film."`.
  - For `cancelled`: `"Téléchargement annulé."`.
- A `"Réessayer"` primary button that re-triggers
  `StartMovieDownloadUseCase.execute(movieId)` and transitions back to
  the download gate.
- A `"Retour"` secondary button that pops the route to the previous
  page (usually the home).

If the download fails **after** `readyToPlay` (mid-playback), the
player SHALL continue playing from the already-buffered portion and
SHALL display a non-blocking snackbar `"Le téléchargement a échoué,
la lecture se poursuit sur la partie déjà téléchargée."` — seeking
past the buffered region continues to be clamped per the seeking
requirement.

#### Scenario: Error state on early failure

- **GIVEN** the download emits `failed` with 200 KB received (below the 2 MiB threshold)
- **WHEN** the PlayerPage receives the event
- **THEN** the download gate is replaced by the error state
- **AND** the message reads `"Impossible de télécharger le film."`
- **AND** the `"Réessayer"` and `"Retour"` buttons are visible

#### Scenario: Post-readyToPlay failure does not interrupt playback

- **GIVEN** playback has started at 1 minute in
- **WHEN** the download subsequently emits `failed`
- **THEN** playback continues
- **AND** a snackbar appears with the degraded-download message
- **AND** seeking past the already-buffered region remains clamped

---

### Requirement: Landscape orientation and immersive UI on mobile

The `PlayerPage` SHALL, on mount, request the following system
settings when running on mobile platforms
(`TargetPlatform.android`, `TargetPlatform.iOS`):

- Preferred orientations = `[landscapeLeft, landscapeRight]`.
- `SystemUiMode.immersiveSticky` to hide status and navigation bars.

On dispose, it SHALL restore:

- Preferred orientations = `[]` (all orientations allowed).
- `SystemUiMode.edgeToEdge`.

On desktop platforms (`TargetPlatform.macOS`, `TargetPlatform.linux`,
`TargetPlatform.windows`), the `PlayerPage` SHALL NOT modify
orientation or system UI mode — the player occupies the widget tree
as-is inside the existing window.

#### Scenario: Mobile enters landscape on mount

- **GIVEN** the app is running on Android
- **WHEN** the `PlayerPage` mounts
- **THEN** `SystemChrome.setPreferredOrientations([landscapeLeft, landscapeRight])` has been invoked
- **AND** `SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky)` has been invoked

#### Scenario: Mobile restores on dispose

- **GIVEN** the `PlayerPage` was mounted on iOS
- **WHEN** the page is disposed
- **THEN** `SystemChrome.setPreferredOrientations([])` has been invoked
- **AND** `SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge)` has been invoked

#### Scenario: Desktop does not modify orientation

- **GIVEN** the app is running on macOS
- **WHEN** the `PlayerPage` mounts
- **THEN** no call to `SystemChrome.setPreferredOrientations` is made
- **AND** no call to `SystemChrome.setEnabledSystemUIMode` is made

---

### Requirement: Wakelock is enabled during active playback

The `PlayerPage` SHALL enable the wakelock (`WakelockPlus.enable()`)
whenever the video is in active playback state. It SHALL disable the
wakelock (`WakelockPlus.disable()`) when:

- The video is paused.
- The page is disposed.
- An error state is rendered.

Wakelock state transitions SHALL be idempotent — calling `enable` while
already enabled is a safe no-op.

#### Scenario: Wakelock enabled on play

- **GIVEN** the player has just transitioned from the download gate to playback
- **THEN** `WakelockPlus.enable()` has been invoked

#### Scenario: Wakelock disabled on pause

- **GIVEN** the video is playing with wakelock enabled
- **WHEN** the user taps pause
- **THEN** `WakelockPlus.disable()` is invoked

#### Scenario: Wakelock re-enabled on resume

- **GIVEN** the video is paused with wakelock disabled
- **WHEN** the user taps play again
- **THEN** `WakelockPlus.enable()` is invoked

#### Scenario: Wakelock disabled on dispose

- **GIVEN** the player is playing with wakelock enabled
- **WHEN** the page is disposed
- **THEN** `WakelockPlus.disable()` is invoked before the player is destroyed

---

### Requirement: Playback orchestration uses application usecases, not the repository directly

The `PlayerPage` SHALL NOT call `DownloadRepository` or
`WatchProgressRepository` methods directly. All access SHALL go
through Application-layer usecases exposed via Riverpod providers:

- `StartMovieDownloadUseCase` — wraps `DownloadRepository.download`,
  returns `Stream<MovieDownloadDto>`.
- `FindMovieDownloadUseCase` — wraps `DownloadRepository.findByMovieId`,
  returns `Future<MovieDownloadDto?>`.
- `CancelMovieDownloadUseCase` — wraps `DownloadRepository.cancel`.
- `DeleteMovieDownloadUseCase` — wraps `DownloadRepository.delete`.
- `GetWatchProgressUseCase` — wraps `WatchProgressRepository.findFor`,
  returns `Future<WatchProgressDto?>`.
- `SaveWatchProgressUseCase` — wraps `WatchProgressRepository.save`,
  accepts a `WatchProgressDto` (or individual fields).

Each usecase SHALL convert between Domain entities and DTOs at its
boundary. No `MovieDownload` or `WatchProgress` Domain entity SHALL
cross the Application/UI boundary.

#### Scenario: UI consumes DTOs only

- **WHEN** the `PlayerPage` observes the download stream
- **THEN** each event is a `MovieDownloadDto`, not a `MovieDownload` Domain entity

#### Scenario: UI saves progress via DTO

- **WHEN** the `PlayerPage` triggers a periodic save
- **THEN** a `WatchProgressDto` (or equivalent scalar params) is passed to `SaveWatchProgressUseCase.execute`
- **AND** no `WatchProgress` Domain entity is manipulated by the UI

