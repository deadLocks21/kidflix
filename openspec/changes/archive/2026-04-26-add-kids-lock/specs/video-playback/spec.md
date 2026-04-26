# Video Playback (kids-lock integration)

Mise à jour de la capability `video-playback` pour acter l'intégration
du bouton de verrouillage dans le `MaterialVideoControlsTheme` du
player. Le comportement effectif du verrouillage (engagement OS,
dialog PIN, déverrouillage, dispose safety) est défini dans la
capability `kids-lock`. Cette modification se limite à la liste des
contrôles présents dans le theme du player et au comportement quand
le state local `_isLocked` du widget est `true`.

## MODIFIED Requirements

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
