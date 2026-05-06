# video-playback Specification

## Purpose
TBD - created by archiving change add-video-playback-and-downloads. Update Purpose after archive.
## Requirements
### Requirement: WatchProgress domain model

The system SHALL define a `sealed class WatchProgress` in
`lib/core/domain/model/watch_progress.dart` exposing the fields
common to all watch progress entries:

- `String get profileId`
- `int get positionSeconds`
- `bool get completed`
- `DateTime get updatedAt`

The sealed hierarchy SHALL contain exactly two variants:

- `MovieProgress` — adds `final String movieId`. Equatable by
  `(profileId, movieId)`.
- `EpisodeProgress` — adds `final String episodeId`. Equatable by
  `(profileId, episodeId)`.

Any switch over `WatchProgress` SHALL be exhaustive at compile-time
without a `default` branch.

The model SHALL NOT include `deviceId` (unchanged from prior version :
multi-device identity is server-side).

The previous `WatchProgress(profileId, movieId, ...)` constructor is
removed ; sites SHALL migrate to either `MovieProgress(...)` or
`EpisodeProgress(...)` explicitly.

#### Scenario: Exhaustive switch over WatchProgress

- **GIVEN** a function that switches on `WatchProgress` runtime type
- **WHEN** a branch for `MovieProgress` or `EpisodeProgress` is omitted
- **THEN** the Dart analyzer emits a non-exhaustive switch error

#### Scenario: MovieProgress equality by profile and movie

- **GIVEN** two `MovieProgress` instances with the same `profileId`
  and `movieId`
- **THEN** `a == b` is true regardless of position or timestamp

#### Scenario: Valid zero-position progress

- **GIVEN** a `MovieProgress` (or `EpisodeProgress`) with
  `positionSeconds = 0`, `completed = false`
- **THEN** the value is valid and represents "never watched past the
  start"

---

### Requirement: WatchProgressRepository domain interface

The system SHALL define a Domain interface `WatchProgressRepository`
in `lib/core/domain/services/watch_progress.repository.dart` :

```dart
abstract interface class WatchProgressRepository {
  Future<MovieProgress?>   findForMovie({
    required String profileId,
    required String movieId,
  });

  Future<EpisodeProgress?> findForEpisode({
    required String profileId,
    required String episodeId,
  });

  Future<void> save(WatchProgress progress);

  Future<List<WatchProgress>> listForProfile(String profileId);
}
```

Contract semantics:

- `findForMovie` — returns the `MovieProgress` for `(profileId,
  movieId)`, or `null` if none. Never throws on missing data.
- `findForEpisode` — returns the `EpisodeProgress` for `(profileId,
  episodeId)`, or `null` if none.
- `save` — accepts the sealed `WatchProgress` and routes internally
  (switch on the sealed) to upsert into the right namespace. The
  sites that call `save` always know the concrete subtype at compile
  time (the player layer).
- `listForProfile` — returns every progress (movies + episodes) for
  the profile in implementation-defined order. The caller is
  responsible for sorting / filtering by kind if desired (the
  application service typically sorts by `updatedAt` desc).

The previous `findFor({profileId, movieId})` method is removed in
favor of the two typed methods. Sites that called the previous
method SHALL migrate explicitly to one or the other.

#### Scenario: findForMovie returns null when no progress

- **GIVEN** the repository has no entry for `(profileId, movieId)`
- **WHEN** `findForMovie(profileId: "p", movieId: "nemo")` is called
- **THEN** the future completes with `null`
- **AND** does NOT throw

#### Scenario: findForEpisode returns null when no progress

- **GIVEN** the repository has no entry for `(profileId, episodeId)`
- **WHEN** `findForEpisode(profileId: "p", episodeId: "s1e3")` is called
- **THEN** the future completes with `null`

#### Scenario: save routes by subtype

- **GIVEN** a `MovieProgress(profileId: "p", movieId: "nemo", ...)` and
  an `EpisodeProgress(profileId: "p", episodeId: "s1e3", ...)`
- **WHEN** `save(...)` is called on each
- **THEN** the movie progress is stored under the movie namespace
- **AND** the episode progress is stored under the episode namespace
- **AND** subsequent `findForMovie` / `findForEpisode` retrieve them
  independently

#### Scenario: listForProfile returns mixed kinds

- **GIVEN** the active profile has one `MovieProgress` and one
  `EpisodeProgress`
- **WHEN** `listForProfile(profileId)` is called
- **THEN** the returned list contains both entries
- **AND** the list type is `List<WatchProgress>` (mixed sealed)

#### Scenario: HTTP repo uses /progress/movies/ and /progress/episodes/ routes

- **GIVEN** a `DioWatchProgressRepository` consuming
  `findForMovie(profileId: "p", movieId: "nemo")` and
  `findForEpisode(profileId: "p", episodeId: "s1e3")`
- **WHEN** the calls are made
- **THEN** the first request hits
  `GET /profiles/p/progress/movies/nemo`
- **AND** the second request hits
  `GET /profiles/p/progress/episodes/s1e3`
- **AND** `listForProfile("p")` hits `GET /profiles/p/progress`

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

The `PlayerPage` widget SHALL accept a `PlayableMedia media` parameter
(the sealed defined in the `series-viewing` capability) instead of the
prior `Movie movie` parameter.

The widget internally switches on the sealed:

- `case Movie m:` → invokes `StartMoviePlaybackUseCase(m)` and saves
  progress as `MovieProgress`.
- `case Episode e:` → invokes `StartEpisodePlaybackUseCase(e)` and
  saves progress as `EpisodeProgress`. The widget MAY accept an
  optional `Series series` parameter passed by the caller (the
  series detail modal already has it loaded) to display the title bar
  as `"{series.title} — S{e.seasonNumber}E{e.episodeNumber} —
  {e.title}"`. When the series is not provided (e.g. from Continue
  Watching), the title bar shows just `"S{n}E{m} — {e.title}"` as a
  graceful fallback.

The `PlayerPage` SHALL NOT make calls to `SeriesRepository` itself —
the parent widget that already has the series in scope passes it
along ; otherwise the player works without it.

The "Lire" button on the movie detail modal continues to construct
the player with a `Movie` ; the episode card on the series detail
modal constructs it with an `Episode` ; the Continue Watching cards
construct it with the corresponding kind.

#### Scenario: PlayerPage with a Movie invokes movie playback

- **GIVEN** a `PlayerPage(media: someMovie)`
- **WHEN** the widget mounts
- **THEN** `StartMoviePlaybackUseCase` is invoked
- **AND** `StartEpisodePlaybackUseCase` is NOT invoked

#### Scenario: PlayerPage with an Episode invokes episode playback

- **GIVEN** a `PlayerPage(media: someEpisode)`
- **WHEN** the widget mounts
- **THEN** `StartEpisodePlaybackUseCase` is invoked
- **AND** `StartMoviePlaybackUseCase` is NOT invoked

#### Scenario: Title bar displays full episode reference when series is provided

- **GIVEN** a `PlayerPage(media: pinguS1E3, series: pinguSeries)`
- **WHEN** rendered
- **THEN** the title bar shows `"Pingu — S1E3 — {episodeTitle}"`

#### Scenario: Title bar shows graceful fallback without series

- **GIVEN** a `PlayerPage(media: pinguS1E3)` (series not passed)
- **WHEN** rendered
- **THEN** the title bar shows `"S1E3 — {episodeTitle}"` (no series
  prefix)

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

In addition, whenever the playback position changes by more than
**2 seconds** between two consecutive events from the engine's
`positionStream` — in either direction — the `PlayerPage` SHALL
invoke `SaveWatchProgressUseCase.execute` with the new position
out-of-band of the periodic timer. This rule captures **user seeks**
(scrubbing the seek bar): a seek is a discontinuity in the position
stream (typical playback delta between events is ≤100ms; a seek
delta is typically several seconds). Saving immediately ensures
multi-device clients see the new position without waiting up to 10s
for the next periodic tick.

The first event of the playback session SHALL NOT trigger a seek
save — there is no baseline to compare against, and the resume
dialog (if shown) already establishes the starting position. Only
deltas computed against a previously-observed position count.

The seek-save SHALL be coalesced with concurrent in-flight saves —
the same single-flight guard used by the periodic save applies. If
a save is already in-flight when a seek is detected, the seek's
save is skipped (the next periodic tick or next seek will pick up
the latest position).

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

#### Scenario: Forward seek triggers an immediate save

- **GIVEN** the video is playing at position 30 seconds
- **WHEN** the user scrubs the seek bar to position 120 seconds
- **AND** the engine emits a position event at 120 seconds
- **THEN** `SaveWatchProgressUseCase.execute` is invoked out-of-band of the periodic timer with `positionSeconds == 120`

#### Scenario: Backward seek triggers an immediate save

- **GIVEN** the video is playing at position 200 seconds
- **WHEN** the user scrubs back to position 10 seconds
- **AND** the engine emits a position event at 10 seconds
- **THEN** `SaveWatchProgressUseCase.execute` is invoked out-of-band of the periodic timer with `positionSeconds == 10`

#### Scenario: Normal playback delta does not trigger a seek save

- **GIVEN** the video is playing at position 30.0 seconds
- **WHEN** the engine emits subsequent position events at 30.05s, 30.10s, 30.15s
- **THEN** no seek-save is invoked
- **AND** only the periodic 10-second saves fire as usual

#### Scenario: First position event does not trigger a seek save

- **GIVEN** playback has just started after a resume to position 1800 seconds
- **WHEN** the very first position event from the engine arrives at 1800 seconds
- **THEN** no seek-save is invoked (no baseline to compare against)

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

### Requirement: HTTP implementation of WatchProgressRepository (DioWatchProgressRepository)

The system SHALL provide an HTTP implementation of the
`WatchProgressRepository` Domain interface in
`lib/infrastructure/watch_progress/dio.watch_progress.repository.dart`,
named `DioWatchProgressRepository`. It SHALL implement the contract
defined by the `WatchProgressRepository domain interface` requirement
verbatim — same method signatures, same semantics — and additionally
satisfy the constraints below.

The class SHALL hit exactly three endpoints, mapping each Domain method
to the corresponding HTTP request documented in `API.md`
§ Progression de lecture:

| Domain method | HTTP request |
|---|---|
| `findFor({profileId, movieId})` | `GET /profiles/{profileId}/progress/{movieId}` |
| `save(WatchProgress progress)` | `PUT /profiles/{progress.profileId}/progress/{progress.movieId}` with JSON body |
| `listForProfile(profileId)` | `GET /profiles/{profileId}/progress` |

The class SHALL receive its `Dio` instance via constructor injection
(`DioWatchProgressRepository({required Dio dio})`). It SHALL NOT
instantiate or look up a `Dio` internally. The `Dio` passed in
production SHALL be the central `dioProvider` instance, configured with
the registered `AuthInterceptor`.

The class SHALL NOT set, read, or modify the `Authorization` header,
the `X-Device-Id` header, or any other auth-related header. Header
injection is the sole responsibility of the `AuthInterceptor` on the
central `Dio`. This is the structural guarantee that the repository
never bypasses or duplicates the auth layer.

The class SHALL NOT perform any metier-level mapping of HTTP errors
into Domain exceptions. Any `4xx`, `5xx`, network error, or any other
`DioException` SHALL propagate to the caller as-is. This aligns with
the posture of `DioCatalogRepository` and is justified by `API.md` not
documenting any specific error code for these endpoints beyond the
global `401 invalid_token` and `404 not_found`, which the client
treats as generic at this stage.

The class SHALL convert between Domain and wire formats via
`RemoteWatchProgressDto`
(`lib/core/application/dtos/remote_watch_progress.dto.dart`). The
repository itself SHALL NOT contain inline JSON keys (snake_case
literals) — that responsibility belongs to the DTO.

#### Scenario: findFor targets the correct path with GET

- **GIVEN** a `DioWatchProgressRepository` whose `Dio` has `baseUrl = 'http://test.local'`
- **WHEN** `findFor(profileId: 'p1', movieId: 'm1')` is called
- **THEN** the underlying `Dio` issues exactly one HTTP request
- **AND** the request method is `GET`
- **AND** the request path is `/profiles/p1/progress/m1`

#### Scenario: findFor returns null on 204 No Content

- **GIVEN** the backend responds with status `204` and an empty body
- **WHEN** `findFor(profileId: 'p1', movieId: 'm1')` is called
- **THEN** the result is `null`
- **AND** no parsing of the body is attempted

#### Scenario: findFor returns null when 200 carries a null body

- **GIVEN** the backend responds with status `200` and `data == null`
- **WHEN** `findFor(profileId: 'p1', movieId: 'm1')` is called
- **THEN** the result is `null`

#### Scenario: findFor maps a 200 JSON body to WatchProgress

- **GIVEN** the backend responds with status `200` and body `{"profile_id": "p1", "movie_id": "m1", "position_seconds": 1845, "completed": false, "updated_at": "2026-04-22T10:30:00Z"}`
- **WHEN** `findFor(profileId: 'p1', movieId: 'm1')` is called
- **THEN** the result is a `WatchProgress` with `profileId == "p1"`, `movieId == "m1"`, `positionSeconds == 1845`, `completed == false`, and `updatedAt` equal to `DateTime.parse("2026-04-22T10:30:00Z")`

#### Scenario: save targets the correct path with PUT and minimal body

- **GIVEN** a `WatchProgress` with `profileId: "p1"`, `movieId: "m1"`, `positionSeconds: 1900`, `completed: false`, `updatedAt: DateTime.utc(2026, 4, 22, 10, 30, 10)`
- **WHEN** `save(progress)` is called
- **THEN** the underlying `Dio` issues exactly one HTTP request
- **AND** the request method is `PUT`
- **AND** the request path is `/profiles/p1/progress/m1`
- **AND** the request body is `{"position_seconds": 1900, "completed": false}`
- **AND** the body does NOT contain the keys `profile_id`, `movie_id`, or `updated_at` (server-stamped)

#### Scenario: save discards the response body

- **GIVEN** the backend responds with status `200` and a body unrelated to what the client sent
- **WHEN** `save(progress)` is called
- **THEN** the call completes successfully with `Future<void>`
- **AND** no parsing of the response body is attempted

#### Scenario: listForProfile targets the correct path with GET

- **WHEN** `listForProfile('p1')` is called
- **THEN** the underlying `Dio` issues exactly one HTTP request
- **AND** the request method is `GET`
- **AND** the request path is `/profiles/p1/progress`

#### Scenario: listForProfile returns an empty list when the array is empty

- **GIVEN** the backend responds with status `200` and body `{"progress": []}`
- **WHEN** `listForProfile('p1')` is called
- **THEN** the result is an empty `List<WatchProgress>`

#### Scenario: listForProfile maps every entry of the array

- **GIVEN** the backend responds with status `200` and body `{"progress": [<entry1>, <entry2>]}` where each entry has the wire shape of a `WatchProgress`
- **WHEN** `listForProfile('p1')` is called
- **THEN** the result is a `List<WatchProgress>` of length 2
- **AND** each element corresponds to its respective wire entry, with all fields parsed correctly

#### Scenario: 4xx propagates as DioException without metier mapping

- **GIVEN** the backend responds with status `404` to a `findFor` request
- **WHEN** `findFor(profileId: 'p1', movieId: 'unknown')` is called
- **THEN** the call throws a `DioException`
- **AND** no Domain-level exception is constructed by the repository

#### Scenario: 5xx propagates as DioException

- **GIVEN** the backend responds with status `500` to a `save` request
- **WHEN** `save(progress)` is called
- **THEN** the call throws a `DioException`

#### Scenario: Repository never sets the Authorization header

- **GIVEN** a `DioWatchProgressRepository` whose `Dio` has no `AuthInterceptor` registered
- **WHEN** any of `findFor`, `save`, or `listForProfile` is called
- **THEN** the captured outbound request has no `Authorization` header set by the repository code

---

### Requirement: WatchProgressRepository implementation selection via API_BASE_URL

The system SHALL select the active `WatchProgressRepository`
implementation based on the compile-time constant
`String.fromEnvironment('API_BASE_URL')`, in
`lib/infrastructure/providers/watch_progress.repository_provider.dart`:

- When `API_BASE_URL` is the empty string (default for `flutter run` and
  `flutter test` without `--dart-define`), the provider SHALL return
  an instance of `InMemoryWatchProgressRepository`.
- When `API_BASE_URL` is non-empty (e.g.,
  `flutter run --dart-define=API_BASE_URL=http://localhost:8080`), the
  provider SHALL return an instance of `DioWatchProgressRepository`
  constructed with `ref.watch(dioProvider)`.

The provider SHALL be marked `keepAlive: true` so the chosen instance
lives for the entire app session. Switching modes requires a full
rebuild — `String.fromEnvironment` is evaluated at compile time, not at
runtime.

This selection mechanism SHALL be the only switch between
implementations: no runtime toggle, no Settings UI, no per-route
override. This is intentional and aligned with the four other
HTTP-portable repositories (`auth`, `catalog`, `profile-management`,
`downloads`) so a single `--dart-define` flag puts the entire app in
one consistent mode.

The provider SHALL remain overridable in tests via Riverpod's
standard `overrideWithValue` / `overrideWith` mechanisms — the
selection rule applies only to production resolution.

#### Scenario: Default build returns InMemoryWatchProgressRepository

- **GIVEN** the app is built without any `--dart-define=API_BASE_URL` flag
- **WHEN** the `watchProgressRepository` provider is read
- **THEN** the returned instance is of type `InMemoryWatchProgressRepository`

#### Scenario: Build with API_BASE_URL returns DioWatchProgressRepository

- **GIVEN** the app is built with `--dart-define=API_BASE_URL=http://example.com`
- **WHEN** the `watchProgressRepository` provider is read
- **THEN** the returned instance is of type `DioWatchProgressRepository`
- **AND** the instance was constructed with the `Dio` from `dioProvider`

#### Scenario: Test override remains supported

- **GIVEN** a test that overrides `watchProgressRepositoryProvider` with a fake implementation via `ProviderContainer(overrides: [...])`
- **WHEN** any consumer reads the provider
- **THEN** the fake implementation is returned, regardless of the `API_BASE_URL` value

---

### Requirement: RemoteWatchProgressDto wire-format DTO

The system SHALL define a wire-format DTO `RemoteWatchProgressDto` in
`lib/core/application/dtos/remote_watch_progress.dto.dart` that
mediates between the JSON payload of the three watch-progress endpoints
(cf. `API.md` § Progression de lecture) and the Domain `WatchProgress`
entity.

The DTO SHALL expose:

- A const constructor with all five fields required.
- `factory RemoteWatchProgressDto.fromJson(Map<String, dynamic> json)`
  — parses a single watch-progress wire payload.
- `WatchProgress toDomain()` — projects the DTO to its Domain entity.
- `Map<String, dynamic> toWireBody()` — produces the JSON body for
  `PUT /profiles/{pid}/progress/{mid}`. The returned map SHALL contain
  exactly the keys `position_seconds` and `completed`. It SHALL NOT
  contain `profile_id` or `movie_id` (which travel in the URL path),
  nor `updated_at` (which the server stamps from its own clock — any
  client-supplied value would be ignored, and a strict backend parser
  rejects unknown / extra fields with `400 invalid_request`).

The wire schema SHALL be parsed as follows. Note that `updated_at` is
**read-only** from the client's perspective: it is always present in
GET responses but never sent in PUT requests.

| Wire field | Wire type | Direction | DTO field | Domain mapping |
|---|---|---|---|---|
| `profile_id` | `String` | GET only (path on PUT) | `profileId` | direct |
| `movie_id` | `String` | GET only (path on PUT) | `movieId` | direct |
| `position_seconds` | `int` | both | `positionSeconds` | direct |
| `completed` | `bool` | both | `completed` | direct |
| `updated_at` | `String` (ISO 8601) | GET only (server-stamped) | `updatedAt: DateTime` | `DateTime.parse(...)` in `fromJson` |

`fromJson` SHALL NOT silently coerce missing required fields. A missing
required field SHALL surface as a runtime cast/null error during
parsing — fail-fast, aligned with the other `Remote*Dto` parsers.

The DTO SHALL NOT depend on `Dio`, on any repository, or on any
infrastructure concern. Its only Domain dependency is the
`WatchProgress` model.

#### Scenario: fromJson + toDomain build a faithful WatchProgress

- **GIVEN** a wire payload `{"profile_id": "p1", "movie_id": "m1", "position_seconds": 1845, "completed": false, "updated_at": "2026-04-22T10:30:00Z"}`
- **WHEN** `RemoteWatchProgressDto.fromJson(payload).toDomain()` is called
- **THEN** the returned `WatchProgress` has `profileId == "p1"`, `movieId == "m1"`, `positionSeconds == 1845`, `completed == false`, and `updatedAt == DateTime.parse("2026-04-22T10:30:00Z")`

#### Scenario: toWireBody produces the PUT body shape

- **GIVEN** a DTO with `profileId: "p1"`, `movieId: "m1"`, `positionSeconds: 1900`, `completed: false`, `updatedAt: DateTime.utc(2026, 4, 22, 10, 30, 10)`
- **WHEN** `toWireBody()` is called
- **THEN** the returned map equals `{"position_seconds": 1900, "completed": false}`
- **AND** the returned map does NOT contain the key `profile_id`
- **AND** the returned map does NOT contain the key `movie_id`
- **AND** the returned map does NOT contain the key `updated_at`

#### Scenario: toWireBody omits updated_at regardless of input precision

- **GIVEN** a DTO whose `updatedAt` carries non-zero microseconds (e.g., `DateTime.utc(2026, 4, 22, 10, 30, 10, 123, 456)`)
- **WHEN** `toWireBody()` is called
- **THEN** the returned map does NOT contain the key `updated_at`
- **AND** no fractional-second string is constructed by the DTO at all (the field is never serialized — server clock is authoritative)

#### Scenario: fromJson fails fast on missing required field

- **GIVEN** a wire payload missing the `position_seconds` key
- **WHEN** `RemoteWatchProgressDto.fromJson(payload)` is called
- **THEN** the call throws (cast/null error), without silently defaulting

### Requirement: EpisodeProgress domain model

The system SHALL represent an episode watch progress as an immutable
Domain value object `EpisodeProgress` extending the sealed
`WatchProgress` class (see modified requirement below). Its fields:

- `profileId`: stable identifier of the profile (string).
- `episodeId`: stable identifier of the episode (string).
- `positionSeconds`: integer number of seconds from the start of the
  episode (`>= 0`).
- `completed`: boolean flag indicating the episode has been watched
  past the completion threshold (the same threshold used for movies).
- `updatedAt`: `DateTime` of the last save.

`EpisodeProgress` SHALL be equatable by `(profileId, episodeId)` —
two `EpisodeProgress` instances for the same profile/episode are
identical for lookup, regardless of position or timestamp.

`EpisodeProgress` SHALL NOT be considered equal to a `MovieProgress`
even when `episodeId == movieId` (different runtime types).

#### Scenario: EpisodeProgress equality by profile and episode

- **GIVEN** two `EpisodeProgress` instances with the same `profileId`
  and `episodeId` but different `positionSeconds`
- **THEN** `a == b` is true

#### Scenario: EpisodeProgress and MovieProgress with same string ids are not equal

- **GIVEN** a `MovieProgress(profileId: "p", movieId: "x", ...)` and
  an `EpisodeProgress(profileId: "p", episodeId: "x", ...)`
- **THEN** `movieProgress == episodeProgress` is false

---

