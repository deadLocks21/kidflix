# Kids Lock

Verrouillage du player vidéo en cours de lecture pour empêcher l'enfant
de naviguer dans Kidflix ou hors de Kidflix sans saisir le PIN du
profil main. La feature se compose de deux couches :

1. Une couche **UI cross-platform** : le `MaterialVideoControlsTheme`
   du player bascule entre un thème "unlocked" (avec tous les contrôles
   normaux + un bouton 🔒) et un thème "locked" (tous les contrôles et
   gestures sont supprimés sauf un bouton de déverrouillage).
2. Une couche **OS Android-only** : un `MethodChannel` natif appelle
   `Activity.startLockTask()` / `stopLockTask()` pour épingler l'app à
   l'écran.

Le déverrouillage exige le PIN du main profile, vérifié localement via
le `VerifyManagementPinUseCase` existant. Aucun nouveau usecase n'est
introduit.

Ne couvre PAS :
- Le lock automatique à l'ouverture du player (manuel uniquement).
- Le lock hors player (la feature est strictement player-locale).
- iOS Guided Access programmatique (impossible — aucun API Apple
  équivalent).
- Le mode Device Owner / kiosk Android (provisioning MDM).
- Le déverrouillage biométrique (PIN uniquement).
- Le rate limiting / lockout client-side après plusieurs PIN incorrects.

## ADDED Requirements

### Requirement: KidsLockService domain interface

The system SHALL define a Domain interface `KidsLockService` in
`lib/core/domain/services/kids_lock.service.dart` exposing:

```dart
abstract interface class KidsLockService {
  Future<bool> startLock();
  Future<bool> stopLock();
  Future<bool> isLocked();
}
```

Contract semantics:

- `startLock` SHALL attempt to engage the OS-level lock. It SHALL
  return `true` if the lock is engaged, `false` otherwise (platform
  not supported, native plugin missing, native exception, or system
  prompt declined by the user). Never throws.
- `stopLock` SHALL attempt to disengage the OS-level lock. It SHALL
  be idempotent — return `true` even if no lock was active. Never
  throws.
- `isLocked` SHALL return the current OS-level lock state. Returns
  `false` on platforms where lock is not supported. Never throws.

The interface SHALL be pure Dart — no Flutter, Riverpod, or HTTP
imports.

The interface SHALL govern the OS-level lock layer only. The UI-level
lock (suppression of player controls) is owned by the player widget
state and does NOT pass through this service.

#### Scenario: Service contract is platform-agnostic

- **GIVEN** the interface `KidsLockService`
- **THEN** any implementation can be substituted without changing the
  caller signature
- **AND** the three methods always return `Future<bool>`, never throw

#### Scenario: stopLock is idempotent

- **GIVEN** an implementation of `KidsLockService` where no lock is
  currently engaged
- **WHEN** `stopLock()` is called
- **THEN** the future completes with `true`
- **AND** no exception is thrown

---

### Requirement: PlatformChannelKidsLockService for Android

The system SHALL provide an Android implementation
`PlatformChannelKidsLockService implements KidsLockService` in
`lib/infrastructure/kids_lock/platform_channel.kids_lock.service.dart`
that bridges to native Android via a `MethodChannel`.

The channel SHALL be named exactly `fr.dtfh.kidflix/app_lock`. The
methods sent over the channel SHALL be named exactly:

- `startLockTask`
- `stopLockTask`
- `isLockTaskMode`

Each native call returns a `bool`. The Dart side SHALL treat a `null`
response as `false`.

The implementation SHALL maintain an internal `bool _isNativeAvailable`
flag (per-instance) initialized to `true`. When a `PlatformException`
with `code == 'MissingPluginException'` is caught on any of the three
methods, the implementation SHALL set `_isNativeAvailable = false` so
subsequent calls short-circuit:

- `startLock`: returns `false` without invoking the channel.
- `stopLock`: returns `true` without invoking the channel (semantics
  "nothing to stop").
- `isLocked`: returns `false` without invoking the channel.

Other `PlatformException`s (e.g. `SecurityException`, `IllegalStateException`)
SHALL cause the current call to return a sensible default (`false` for
`startLock` and `isLocked`, `true` for `stopLock`) but SHALL NOT
disable `_isNativeAvailable` for future calls — these are recoverable
runtime errors, not "plugin missing" signals.

The implementation SHALL NOT log raw native exception messages (no
PII at risk, but keeps logs clean).

#### Scenario: Nominal startLock succeeds

- **GIVEN** the native side responds `true` to `startLockTask`
- **WHEN** `startLock()` is called
- **THEN** the future completes with `true`

#### Scenario: MissingPlugin disables future calls

- **GIVEN** a fresh `PlatformChannelKidsLockService` instance
- **WHEN** `startLock()` is called and the channel throws
  `PlatformException(code: 'MissingPluginException')`
- **THEN** the future completes with `false`
- **WHEN** `startLock()` is called again
- **THEN** the channel is NOT invoked
- **AND** the future completes with `false`

#### Scenario: stopLock returns true when native is unavailable

- **GIVEN** a `PlatformChannelKidsLockService` where `_isNativeAvailable
  == false`
- **WHEN** `stopLock()` is called
- **THEN** the channel is NOT invoked
- **AND** the future completes with `true`

#### Scenario: Other PlatformException does not disable the service

- **GIVEN** a `PlatformChannelKidsLockService`
- **WHEN** `startLock()` is called and the channel throws
  `PlatformException(code: 'SecurityException')`
- **THEN** the future completes with `false`
- **WHEN** `startLock()` is called again
- **THEN** the channel IS invoked again

---

### Requirement: NoopKidsLockService for non-Android platforms

The system SHALL provide a fallback implementation
`NoopKidsLockService implements KidsLockService` in
`lib/infrastructure/kids_lock/noop.kids_lock.service.dart` that does
nothing and returns hardcoded values:

- `startLock()` → `Future.value(false)`
- `stopLock()` → `Future.value(true)`
- `isLocked()` → `Future.value(false)`

The implementation SHALL have no side effects (no logs, no analytics,
no exception risk).

This implementation SHALL be used on iOS, web, macOS, Linux, Windows.

#### Scenario: NoopKidsLockService matches the contract silently

- **GIVEN** an instance of `NoopKidsLockService`
- **WHEN** `startLock()`, `stopLock()`, and `isLocked()` are each
  called
- **THEN** they return `false`, `true`, `false` respectively
- **AND** no exception is thrown
- **AND** no I/O or platform call is performed

---

### Requirement: kidsLockServiceProvider auto-selects implementation by platform

The system SHALL expose a Riverpod provider `kidsLockServiceProvider`
in `lib/infrastructure/providers/kids_lock.service_provider.dart` that
returns:

- `PlatformChannelKidsLockService()` when
  `defaultTargetPlatform == TargetPlatform.android`
- `NoopKidsLockService()` otherwise

The selection SHALL be evaluated once at provider creation and SHALL
NOT be reactive — `defaultTargetPlatform` is constant for the lifetime
of the app.

The provider SHALL be overridable in tests via the standard Riverpod
override mechanism so a fake can be injected.

#### Scenario: Android boot uses PlatformChannel implementation

- **GIVEN** the app runs on Android (`defaultTargetPlatform ==
  TargetPlatform.android`)
- **WHEN** any consumer reads `kidsLockServiceProvider`
- **THEN** the returned instance is of runtime type
  `PlatformChannelKidsLockService`

#### Scenario: iOS boot uses Noop implementation

- **GIVEN** the app runs on iOS
- **WHEN** any consumer reads `kidsLockServiceProvider`
- **THEN** the returned instance is of runtime type
  `NoopKidsLockService`

#### Scenario: Test override injects a fake

- **GIVEN** a test that overrides `kidsLockServiceProvider` with a
  `_FakeKidsLockService`
- **WHEN** the widget under test consumes the provider
- **THEN** the fake is returned regardless of `defaultTargetPlatform`

---

### Requirement: Native Android MethodChannel handler in MainActivity

The Android `MainActivity` SHALL register a `MethodChannel` named `fr.dtfh.kidflix/app_lock` on the Flutter engine's `dartExecutor.binaryMessenger` during `configureFlutterEngine`. The activity file path is `android/app/src/main/kotlin/fr/dtfh/kidflix/MainActivity.kt`.

The channel handler SHALL dispatch on `call.method`:

- `"startLockTask"` → call `Activity.startLockTask()`. On success,
  reply `result.success(true)`. On exception (e.g. `IllegalStateException`,
  `SecurityException`), reply `result.success(false)`.
- `"stopLockTask"` → call `Activity.stopLockTask()`. On success,
  reply `result.success(true)`. On exception, reply
  `result.success(false)`.
- `"isLockTaskMode"` → return whether the activity is currently in
  lock task mode. On Android M+ (API 23+), use
  `ActivityManager.lockTaskModeState != ActivityManager.LOCK_TASK_MODE_NONE`.
  On API 21–22, use the deprecated `ActivityManager.isInLockTaskMode()`.
  Reply `result.success(<bool>)`.
- Any other method → reply `result.notImplemented()`.

Native exceptions SHALL be caught at the handler boundary — they
SHALL NOT propagate to the Flutter engine as `PlatformException`s
unless they are `MissingPluginException` (which only occurs when the
handler is not registered at all). Documenting the channel registration
in `MainActivity.kt`'s `configureFlutterEngine` is sufficient to keep
this guarantee.

The implementation SHALL NOT require any AndroidManifest.xml change.
`startLockTask` in non-Device-Owner mode shows a system confirmation
prompt the first time per device — this is acceptable UX for this
change.

#### Scenario: startLockTask method engages OS lock

- **GIVEN** Kidflix is running on an Android device, foreground
- **WHEN** the Flutter side invokes `_channel.invokeMethod('startLockTask')`
- **THEN** the native handler calls `Activity.startLockTask()`
- **AND** the channel replies `true`
- **AND** (first time only per device) the system displays the
  "Pin this screen?" confirmation prompt

#### Scenario: Unknown method returns notImplemented

- **WHEN** the Flutter side invokes `_channel.invokeMethod('whatever')`
- **THEN** the channel replies with `MissingPluginException`-like
  `notImplemented` error

#### Scenario: Native exception is caught at handler boundary

- **GIVEN** `Activity.startLockTask()` throws `IllegalStateException`
  (e.g. activity not foregrounded)
- **WHEN** the handler catches the exception
- **THEN** the channel replies `result.success(false)`
- **AND** no `PlatformException` propagates to Flutter

---

### Requirement: Player exposes a lock toggle button

The `PlayerPage` SHALL expose a single toggle button to engage and
disengage the kids lock. The button SHALL be rendered inside the
existing `MaterialVideoControlsThemeData.bottomButtonBar`, after the
`MaterialFullscreenButton`. Its visual style SHALL match the other
material video control buttons (white icon, default size, default
hover behavior).

The button SHALL display:

- `Icons.lock_outline` (open padlock) when the player is unlocked.
- `Icons.lock` (closed padlock) when the player is locked.

A `Tooltip` SHALL be set with the French strings `"Verrouiller"` /
`"Déverrouiller"` respectively.

The button SHALL be visible only when `MaterialVideoControls` reveals
the controls (tap on video, auto-hide cycle) — same visibility
behavior as the other buttons. No always-visible affordance.

The unlock variant of this button (with `Icons.lock` closed padlock) SHALL be present in the locked-state bottom button bar alongside the comfort controls (play/pause, position, fullscreen, and on desktop volume) — see the locked-theme requirement for the full list.

The button SHALL NOT appear in any state other than `ProfileSelected`
— since the player route is unreachable from other session states,
this is enforced upstream by the router redirect (no additional
guard required).

The same button SHALL be present on both the mobile theme
(`MaterialVideoControlsThemeData`) and the desktop theme
(`MaterialDesktopVideoControlsThemeData`).

#### Scenario: Lock button is visible in unlocked bottom button bar

- **GIVEN** the player is open and unlocked
- **WHEN** the user taps the video to reveal controls
- **THEN** the bottom button bar shows
  `[MaterialPlayOrPauseButton, MaterialPositionIndicator, Spacer,
  MaterialFullscreenButton, LockButton(open padlock)]`

#### Scenario: Locked bottom button bar keeps comfort controls + unlock

- **GIVEN** the player is open and locked
- **WHEN** the user taps the video to reveal controls
- **THEN** the mobile bottom button bar shows `[MaterialPlayOrPauseButton, MaterialPositionIndicator, Spacer, MaterialFullscreenButton, UnlockButton(closed padlock)]`
- **AND** no `LockButton` (open padlock) is rendered
- **AND** no Close button is rendered (only the movie title remains in the top bar)

---

### Requirement: Tapping the lock engages OS lock and switches to locked theme

The `PlayerPage` SHALL react to a tap on the lock button (when unlocked) by performing three steps in order:

1. Call `KidsLockService.startLock()` and await its result.
2. Set the local state `_isLocked = true` regardless of the return
   value of `startLock()` — the UI lock applies on all platforms,
   even when the OS lock is unavailable or refused by the user.
3. Trigger a `setState` so the `MaterialVideoControlsTheme` rebuilds
   with the locked-state theme.

The transition SHALL NOT be cancellable — once the user taps lock,
the locked theme is immediately applied. A subsequent rebuild can
only happen via the unlock flow.

The transition SHALL NOT pause playback — the video continues
playing while locked.

#### Scenario: Tap on lock engages both layers

- **GIVEN** the player is unlocked and playing
- **WHEN** the user taps the lock button
- **THEN** `KidsLockService.startLock()` is called
- **AND** the local `_isLocked` state becomes `true`
- **AND** the bottom button bar rebuilds with only the unlock button
- **AND** playback continues uninterrupted

#### Scenario: Tap on lock works when OS lock unavailable

- **GIVEN** the player runs on iOS where `KidsLockService` is the
  Noop implementation
- **WHEN** the user taps the lock button
- **THEN** `startLock()` returns `false`
- **AND** the local `_isLocked` state still becomes `true`
- **AND** the bottom button bar rebuilds with only the unlock button

---

### Requirement: Locked theme suppresses exit and seek controls only

The `PlayerPage` SHALL build a locked-state `MaterialVideoControlsThemeData` (and its `MaterialDesktopVideoControlsThemeData` counterpart) when `_isLocked == true`, suppressing only the controls that let the kid exit the player or skip the movie. Comfort controls (play/pause, position, volume, brightness, fullscreen) remain available.

| Field | Unlocked value | Locked value |
|-------|----------------|--------------|
| `displaySeekBar` | `true` (default) | `false` |
| `seekGesture` | `true` (default) | `false` |
| `volumeGesture` | `true` (default) | `true` (kept) |
| `brightnessGesture` | `true` (default) | `true` (kept) |
| `seekOnDoubleTap` | `false` (already) | `false` |
| `speedUpOnLongPress` | `false` (already) | `false` |
| `topButtonBar` | `[close, title]` | `[title]` |
| `primaryButtonBar` | `[]` (default empty) | `const []` |
| `bottomButtonBar` (mobile) | `[play, position, Spacer, fullscreen, lock]` | `[play, position, Spacer, fullscreen, unlock]` |
| `bottomButtonBar` (desktop) | `[play, volume, position, Spacer, fullscreen, lock]` | `[play, volume, position, Spacer, fullscreen, unlock]` |

The locked-state theme SHALL block exactly:

- The Close button (removed from the top button bar; only the movie title remains).
- The seek bar (`displaySeekBar: false`) and any seek-related gesture (`seekGesture: false`, `seekOnDoubleTap: false`).

The locked-state theme SHALL keep enabled:

- The play/pause button.
- The position indicator (display only — no seek control attached).
- The volume gesture and (on desktop) the volume button.
- The brightness gesture.
- The fullscreen button.

The seek bar margins (`seekBarMargin`) and other layout-only fields MAY remain unchanged — they have no visible effect when `displaySeekBar: false`.

The `visibleOnMount`, `controlsHoverDuration`, and tap-to-toggle visibility behaviors SHALL remain unchanged — locked-state controls appear on tap and auto-hide after the configured duration, exactly like in the unlocked state.

#### Scenario: Seek-related gestures disabled when locked

- **GIVEN** the player is locked
- **WHEN** the user swipes horizontally on the video surface
- **THEN** no seek occurs
- **WHEN** the user double-taps on the left or right half of the video
- **THEN** no skip occurs

#### Scenario: Volume and brightness gestures remain active when locked

- **GIVEN** the player is locked
- **WHEN** the user swipes vertically on the left half of the video
- **THEN** the brightness changes
- **WHEN** the user swipes vertically on the right half of the video
- **THEN** the volume changes

#### Scenario: Top bar keeps title but drops close button when locked

- **GIVEN** the player is locked and the movie title is `"Totoro"`
- **WHEN** the user taps to reveal controls
- **THEN** the top button bar shows the text `"Totoro"`
- **AND** no Close button is rendered

#### Scenario: Seek bar hidden when locked

- **GIVEN** the player is locked
- **WHEN** the user taps to reveal controls
- **THEN** no seek bar is rendered

#### Scenario: Comfort controls remain in the locked bottom bar

- **GIVEN** the player is locked
- **WHEN** the user taps to reveal controls
- **THEN** the bottom button bar contains the play/pause button, the position indicator, the fullscreen button, and the unlock button
- **AND** (desktop only) the volume button is also present

---

### Requirement: Tapping the unlock button opens a PIN dialog

The `PlayerPage` SHALL display a modal PIN dialog (`showUnlockPinDialog`) when the user taps the unlock button while `_isLocked == true`. The dialog contract is the following:

1. Resolves the main profile from the current session via
   `session.profiles.firstWhere((p) => p.isMain)`.
2. Renders an input field for a PIN.
3. On submit, calls `VerifyManagementPinUseCase.execute(
   mainProfile: ..., rawPin: ...)`.
4. On `VerifyManagementPinSuccess`, dismisses the dialog and signals
   success to the caller (`Future<bool>` resolves to `true`).
5. On `VerifyManagementPinInvalid`, displays an inline error message
   (e.g. *"Code incorrect"*), clears the input field, and keeps the
   dialog open for retry.
6. Provides an explicit "Annuler" action that dismisses the dialog
   and signals failure (`Future<bool>` resolves to `false`).

The dialog SHALL NOT impose any client-side rate limit or cooldown
on incorrect attempts — consistent with the existing
`VerifyManagementPinUseCase` contract for the management mode entry.

The raw PIN string SHALL NEVER be stored, logged, or persisted
beyond the single `verify` call.

The dialog UI SHALL match the visual style of the existing PIN
dialogs in the app (e.g. those used in `lib/ui/pages/profile_pin/`
and the management PIN flow).

#### Scenario: Correct PIN dismisses dialog with success

- **GIVEN** the player is locked and the main profile has
  `pinHash = bcrypt("1234")`
- **WHEN** the user taps the unlock button
- **AND** the user enters `"1234"` and submits
- **THEN** `VerifyManagementPinUseCase` returns `Success`
- **AND** the dialog is dismissed
- **AND** the dialog future resolves to `true`

#### Scenario: Incorrect PIN keeps dialog open

- **GIVEN** the player is locked and the main profile has
  `pinHash = bcrypt("1234")`
- **WHEN** the user taps the unlock button
- **AND** the user enters `"0000"` and submits
- **THEN** `VerifyManagementPinUseCase` returns `Invalid`
- **AND** the dialog remains visible
- **AND** an inline error message is displayed
- **AND** the input field is cleared

#### Scenario: Cancel dismisses dialog with failure

- **GIVEN** the player is locked and the unlock dialog is open
- **WHEN** the user taps the Cancel button
- **THEN** the dialog is dismissed
- **AND** the dialog future resolves to `false`

---

### Requirement: Successful unlock disengages OS lock and restores theme

When the unlock dialog returns `true`, the `PlayerPage` SHALL:

1. Call `KidsLockService.stopLock()` and await its result.
2. Set the local state `_isLocked = false` regardless of the return
   value of `stopLock()`.
3. Trigger a `setState` so the `MaterialVideoControlsTheme` rebuilds
   with the unlocked-state theme.

When the unlock dialog returns `false` (cancel or never matched), the
state SHALL NOT change — `_isLocked` remains `true`, no
`stopLock()` call is made, and the player remains in locked theme.

#### Scenario: Successful unlock restores controls

- **GIVEN** the player is locked
- **WHEN** the user taps unlock and enters the correct PIN
- **THEN** `KidsLockService.stopLock()` is called
- **AND** the local `_isLocked` becomes `false`
- **AND** the bottom button bar rebuilds with `[play, position,
  Spacer, fullscreen, lock]`
- **AND** the seek bar reappears
- **AND** all gestures are re-enabled

#### Scenario: Cancel preserves locked state

- **GIVEN** the player is locked
- **WHEN** the user taps unlock and cancels the PIN dialog
- **THEN** `KidsLockService.stopLock()` is NOT called
- **AND** the local `_isLocked` remains `true`
- **AND** the player UI stays in locked theme

---

### Requirement: Player dispose stops the OS lock as a safety net

The `PlayerPage`'s `dispose()` method SHALL call
`KidsLockService.stopLock()` unconditionally, regardless of the
current value of `_isLocked`.

This SHALL be implemented as `unawaited(_kidsLock.stopLock())` (since
`dispose()` is synchronous and we cannot await). The `KidsLockService`
contract guarantees `stopLock` never throws, so the unawaited future
is safe.

The reference to the service SHALL be cached in a field on the
`State` (e.g. via `ref.read(kidsLockServiceProvider)` during
`initState`), since `dispose()` cannot safely access `ref`.

#### Scenario: Dispose unlocks even if state is unlocked

- **GIVEN** the player is unlocked (nominal state)
- **WHEN** the widget is disposed (user taps close)
- **THEN** `KidsLockService.stopLock()` is called
- **AND** the call returns gracefully (no-op on Android since no
  active lock task; no-op on Noop)

#### Scenario: Dispose unlocks unexpected zombie lock

- **GIVEN** the player is locked but the widget is being disposed
  via an unexpected path (hot reload, OS kill mid-frame, future bug)
- **WHEN** `dispose()` runs
- **THEN** `KidsLockService.stopLock()` is called
- **AND** the OS-level lock task is released

---

### Requirement: Lock state is volatile and player-local

The `_isLocked` boolean SHALL be local state of `_PlayerPageState`
only. It SHALL NOT be persisted to `SharedPreferences`, written to
the session controller, exposed as a Riverpod provider, or carried
across navigations.

When the player is disposed (close button, navigation back, route
pop, app kill), `_isLocked` SHALL be discarded along with the rest
of the widget state.

When the player is reopened after being closed, the new instance
SHALL start in the unlocked state.

If the app process is killed by the OS while the lock is engaged,
Android SHALL automatically clean up the lock task at process
termination (documented native behavior). On app relaunch, the
session is restored to `Authenticated` (per existing `profile-selection`
spec — active profile is volatile), so the player route is no longer
reachable until the user re-selects a profile.

#### Scenario: New player instance starts unlocked

- **GIVEN** a previous player instance was locked then closed via
  unlock + close
- **WHEN** the user opens a new player for a different movie
- **THEN** the new player starts in unlocked state
- **AND** the lock button shows `Icons.lock_outline`

#### Scenario: App kill while locked cleans up natively

- **GIVEN** the player is locked on Android
- **WHEN** the OS kills the app process (e.g. low memory)
- **THEN** Android removes the lock task automatically
- **AND** the home screen becomes accessible normally

---

### Requirement: Native code requires no manifest or permission changes

The implementation SHALL NOT modify `AndroidManifest.xml`. The
`startLockTask` API in non-Device-Owner mode does not require any
manifest declaration nor any runtime permission.

The implementation SHALL NOT raise the `minSdkVersion`. The
`startLockTask`/`stopLockTask` APIs are available since API 21
(Lollipop). The `isInLockTaskMode` query uses the API 23+ method
when available and falls back to the deprecated API 21 method
otherwise.

#### Scenario: Manifest is unchanged

- **WHEN** this change is applied
- **THEN** the `android/app/src/main/AndroidManifest.xml` file is
  unchanged from before the change

#### Scenario: minSdkVersion is unchanged

- **WHEN** this change is applied
- **THEN** the `android/app/build.gradle` (or `.kts`) `minSdkVersion`
  is unchanged from before the change
