## ADDED Requirements

### Requirement: DownloadEntry domain model

The system SHALL represent an inventory item — the parent-facing view of
something present on disk — as an immutable Domain value object
`DownloadEntry` in
`lib/core/domain/model/download_entry.dart` (or co-located with the
existing download models).

`DownloadEntry` SHALL aggregate, for a single downloaded media item:

- `mediaId`: the stable identifier (movie or episode id).
- `mediaKind`: one of `movie | episode`.
- `kind`: `DownloadKind` (`cache | download`) — see the `downloads`
  capability.
- `bytesOnDisk`: actual file size on disk, sum of `.mp4` and any
  remaining `.partial` for that id.
- `completedAt`: nullable `DateTime` — non-null only when the
  download has reached `complete`.
- `lastPlayedAt`: nullable `DateTime` — non-null when the player has
  ever opened this item.
- `triggeredByProfileId`: nullable string — the profile id that
  initiated the download. Null for items present on disk but absent
  from the manifest (rétro-classified entries).
- `displayTitle`: the resolved title from catalog/series metadata, or
  the literal `"Vidéo inconnue"` when the catalog lookup fails.
- `displayPosterUrl`: nullable poster URL from catalog/series metadata.
- `parentSeriesTitle`: nullable string, populated only for episodes.

`DownloadEntry` SHALL be equatable by `(mediaKind, mediaId)`.

`DownloadEntry` SHALL NOT be exposed by `DownloadRepository` directly —
only `ListDownloadsUseCase` constructs it by combining the repository
output with `CatalogRepository` / `SeriesRepository` lookups.

#### Scenario: DownloadEntry for a downloaded movie

- **GIVEN** a movie `"abc"` is on disk at 450 MB, classified `download`, completed yesterday, last played today, triggered by profile `"marie"`
- **AND** the catalog returns a movie with title `"Le Roi Lion"` and a poster URL
- **WHEN** the entry is built
- **THEN** the `DownloadEntry` has `mediaKind: movie`, `bytesOnDisk: 471_859_200`, `kind: download`, `displayTitle: "Le Roi Lion"`, `parentSeriesTitle: null`

#### Scenario: DownloadEntry for an episode resolves the series

- **GIVEN** an episode `"pingu-s01e04"` of series `"pingu"` is on disk
- **AND** the series repository returns the series with title `"Pingu"` and the episode with title `"Pingu skateur"`
- **WHEN** the entry is built
- **THEN** `displayTitle == "Pingu skateur"`
- **AND** `parentSeriesTitle == "Pingu"`

#### Scenario: DownloadEntry falls back when catalog lookup fails

- **GIVEN** a file on disk for media id `"unknown-xyz"` whose catalog/series lookup returns `null`
- **WHEN** the entry is built
- **THEN** `displayTitle == "Vidéo inconnue"`
- **AND** `displayPosterUrl == null`
- **AND** the entry is still listed (the parent must be able to clean it up)

---

### Requirement: DownloadCleanupService Domain interface

The system SHALL define a Domain interface `DownloadCleanupService` in
`lib/core/domain/services/download_cleanup.service.dart`:

```dart
abstract interface class DownloadCleanupService {
  Future<int> runCacheCleanup({
    required Duration olderThan,
    required DateTime now,
  });
}
```

`runCacheCleanup` SHALL:

1. Enumerate all downloads via `DownloadRepository.listAll()`.
2. Filter to items where `kind == cache`.
3. Filter further to items where `lastPlayedAt` is non-null and
   `now - lastPlayedAt > olderThan`. Items with a `null`
   `lastPlayedAt` (never played) SHALL NOT be cleaned by this rule —
   they remain on disk indefinitely until manual deletion or until
   they are eventually played and 30 days pass.
4. Call `deleteMovie(id)` or `deleteEpisode(id)` on each matching
   item, in sequence (not parallel) to avoid concurrent manifest
   writes.
5. Return the count of items successfully deleted.

`runCacheCleanup` SHALL be idempotent: calling it twice in a row
SHALL leave state unchanged after the first call (the second
returns `0`).

`runCacheCleanup` SHALL be best-effort: if `deleteMovie/Episode`
throws on one item, the service SHALL log a warning and continue
with the next item. The returned count reflects only successful
deletions.

The service SHALL NOT make HTTP calls. It operates entirely on the
local repository.

#### Scenario: Cleanup removes only stale cache items

- **GIVEN** the inventory contains:
  - `movies/abc` kind=download, lastPlayedAt 60 days ago
  - `movies/def` kind=cache, lastPlayedAt 60 days ago
  - `movies/ghi` kind=cache, lastPlayedAt 5 days ago
  - `episodes/jkl` kind=cache, lastPlayedAt null (never played)
- **WHEN** `runCacheCleanup(olderThan: Duration(days: 30), now: today)` is called
- **THEN** only `movies/def` is deleted
- **AND** the return value is `1`

#### Scenario: Cleanup is idempotent

- **GIVEN** `runCacheCleanup` has just deleted 3 items
- **WHEN** `runCacheCleanup` is called again with the same arguments
- **THEN** the return value is `0`
- **AND** no items are touched

#### Scenario: Cleanup continues past per-item failure

- **GIVEN** the inventory contains 5 stale cache items
- **AND** `deleteMovie(id3)` throws an `IOException`
- **WHEN** `runCacheCleanup` is called
- **THEN** items 1, 2, 4, 5 are deleted
- **AND** the return value is `4`
- **AND** a warning is logged for item 3

---

### Requirement: DeviceStorageProbe Domain interface

The system SHALL define a Domain interface `DeviceStorageProbe` in
`lib/core/domain/services/device_storage_probe.dart`:

```dart
abstract interface class DeviceStorageProbe {
  Future<int> appDownloadsBytes();
  Future<int?> deviceFreeBytes();
}
```

- `appDownloadsBytes` SHALL return the total bytes occupied by the
  app's downloads directory (sum of `.mp4` and `.partial` files).
  This MAY delegate to `DownloadRepository.totalBytesOnDisk()`.
  Returns `0` if the directory is empty or absent. Never throws.
- `deviceFreeBytes` SHALL return the bytes free on the volume that
  hosts `${applicationDocumentsDirectory}`, or `null` when the
  platform cannot provide it (no plugin available, plugin error,
  unsupported OS). Never throws.

The interface SHALL be pure Dart — no Flutter, Riverpod, or HTTP
imports.

#### Scenario: appDownloadsBytes sums all download files

- **GIVEN** the downloads directory contains a 450 MB `.mp4` and a 100 MB `.partial`
- **WHEN** `appDownloadsBytes()` is called
- **THEN** the result is `577_241_088` (550 MB)

#### Scenario: deviceFreeBytes returns null when probe unavailable

- **GIVEN** an implementation of `DeviceStorageProbe` that has no
  underlying disk-space plugin
- **WHEN** `deviceFreeBytes()` is called
- **THEN** the result is `null`
- **AND** no exception is thrown

---

### Requirement: ListDownloadsUseCase splits inventory into downloads and cache

The system SHALL expose `ListDownloadsUseCase` (Application layer) with:

```dart
class DownloadInventory {
  final List<DownloadEntry> downloads; // kind == download
  final List<DownloadEntry> cache;     // kind == cache
}

class ListDownloadsUseCase {
  Future<DownloadInventory> execute({List<String> profileIds = const []});
}
```

`execute` SHALL:

1. Call `DownloadRepository.listAll()` to obtain raw inventory records.
2. Build a catalog index by calling
   `CatalogRepository.listCatalogForProfile(profileId)` once per id
   in [profileIds] and unioning the results — this works around the
   strict-equality age filter on `/catalog` (cf. catalog capability).
   When [profileIds] is empty, fall back to a single
   `listCatalog()` call (legacy / in-memory).
3. For each record, decorate with display fields, resolved in this
   priority order:
   * `record.cachedTitle` / `cachedPosterUrl` / `cachedParentSeriesTitle`
     (manifest fields written by
     [DownloadRepository.cacheMediaMetadata]) — IMMUNE to the age
     filter. Always preferred when present.
   * Catalog/series lookup result.
   * Fallback literal `"Vidéo inconnue · <8-char id prefix>"`.
4. For episodes, resolve the parent series via
   `SeriesRepository.findByIdForProfile(seriesId, profileId)`, where
   `profileId` is whichever family profile exposed the series in
   step 2. This permits resolving series above the parent's age
   category.
5. Partition by `kind` into `downloads` and `cache`.
6. Sort each list by `lastPlayedAt` descending (most recent on top).
   Entries with `lastPlayedAt == null` SHALL appear at the end of
   their list, sub-sorted by `completedAt` descending (then by
   `mediaId` for ties).
7. Return the resulting `DownloadInventory`.

`execute` SHALL handle catalog/series lookup errors gracefully: a
per-profile catalog failure is logged and skipped (the union goes
on); a per-item catalog/series miss falls back to the cached fields
or the literal — never fails the whole call.

#### Scenario: Downloads and cache are partitioned and sorted

- **GIVEN** 4 items on disk: 2 download (last played 1d ago, 5d ago), 2 cache (last played 2d ago, never)
- **WHEN** `execute()` is called
- **THEN** `downloads.length == 2`, ordered `[1d, 5d]`
- **AND** `cache.length == 2`, ordered `[2d, never]`

#### Scenario: Catalog lookup failure falls back per-entry

- **GIVEN** the catalog returns `null` for one of three downloaded movies
- **WHEN** `execute()` is called
- **THEN** all three entries are returned
- **AND** the unresolved one has `displayTitle == "Vidéo inconnue"`

---

### Requirement: MarkAsDownloadUseCase and MarkAsCacheUseCase

The system SHALL expose two Application use cases:

```dart
class MarkAsDownloadUseCase {
  Future<void> execute({required String mediaId, required bool isEpisode});
}

class MarkAsCacheUseCase {
  Future<void> execute({required String mediaId, required bool isEpisode});
}
```

Both use cases SHALL be a thin call into `DownloadRepository.setMovieKind`
or `setEpisodeKind`. They do NOT perform the kids-lock challenge —
that is a UI-layer concern (cf. catalog spec). The use case is
called only after the challenge has passed (or skipped if the
active profile is the parent).

`MarkAsDownloadUseCase` SHALL set `kind = DownloadKind.download`.
`MarkAsCacheUseCase` SHALL set `kind = DownloadKind.cache`.

Both SHALL be idempotent: re-marking an item already in the target
kind is a no-op (no manifest write, no error).

Calling either use case on a media id that has no file on disk and
no manifest entry SHALL be a no-op (no error, no entry created in
the manifest). The semantics: there is nothing to mark.

#### Scenario: MarkAsDownload promotes a cache item

- **GIVEN** `movies/abc` exists on disk with `kind == cache`
- **WHEN** `MarkAsDownloadUseCase.execute(mediaId: "abc", isEpisode: false)`
- **THEN** the manifest entry for `movies/abc` has `kind == download`
- **AND** the file on disk is unchanged

#### Scenario: MarkAsCache demotes a download item

- **GIVEN** `episodes/pingu-s01e04` exists on disk with `kind == download`
- **WHEN** `MarkAsCacheUseCase.execute(mediaId: "pingu-s01e04", isEpisode: true)`
- **THEN** the manifest entry has `kind == cache`
- **AND** the entry becomes eligible for auto-cleanup

#### Scenario: Idempotent re-marking is a no-op

- **GIVEN** `movies/abc` is already `kind == download`
- **WHEN** `MarkAsDownloadUseCase.execute(...)` is called
- **THEN** the call completes
- **AND** no manifest write occurs

---

### Requirement: DownloadSeasonUseCase downloads episodes sequentially

The system SHALL expose:

```dart
class DownloadSeasonUseCase {
  Stream<DownloadSeasonProgress> execute({
    required String seriesId,
    required int seasonNumber,
  });
}

class DownloadSeasonProgress {
  final int totalEpisodes;
  final int doneEpisodes;
  final String currentEpisodeId;
  final EpisodeDownload currentSnapshot;
}
```

`execute` SHALL:

1. Resolve the series via `SeriesRepository.findById(seriesId)`.
2. Find the requested season ; collect its episodes ordered by
   `episodeNumber` ascending.
3. Iterate one episode at a time:
   - Subscribe to `DownloadRepository.downloadEpisode(episodeId)`.
   - Emit `DownloadSeasonProgress` snapshots wrapping the
     `EpisodeDownload` events.
   - On terminal status (`complete`), call
     `setEpisodeKind(episodeId, DownloadKind.download)` to mark it
     as a download intent (no auto-clean).
   - On `failed` or `cancelled`, abort the loop — do not auto-skip
     to the next episode (the user retries explicitly).
4. After all episodes complete, close the stream.

`execute` SHALL skip episodes already on disk in `kind == download`
state — they are simply re-marked (idempotent) and the loop moves
on without a new HTTP request.

`execute` SHALL skip episodes already on disk in `kind == cache`
state — they are promoted to `download` and the loop moves on.

The caller's `StreamSubscription.cancel()` SHALL abort the in-flight
episode download (via `cancelEpisode`) and stop the loop.

#### Scenario: Season download proceeds episode by episode

- **GIVEN** Pingu Season 1 has 8 episodes
- **WHEN** `execute(seriesId: "pingu", seasonNumber: 1)` is consumed
- **THEN** the stream emits progress for episode 1, then episode 2, etc., one at a time
- **AND** at no point are two episodes downloading concurrently

#### Scenario: Already-downloaded episode is skipped without HTTP

- **GIVEN** Season 1 with episodes 1–4
- **AND** episode 2 is already on disk as `kind == download`
- **WHEN** the season is downloaded
- **THEN** episode 2 emits a single `complete` snapshot without HTTP

#### Scenario: Cache episode is promoted then skipped

- **GIVEN** episode 3 is on disk as `kind == cache`
- **WHEN** the season is downloaded and the loop reaches episode 3
- **THEN** episode 3 manifest is set to `kind == download`
- **AND** no HTTP request for episode 3 is issued

#### Scenario: Failure aborts the loop

- **GIVEN** Season 1 with 8 episodes, episode 3 fails to download
- **WHEN** the season download runs
- **THEN** episodes 1 and 2 complete and are marked `download`
- **AND** episode 3 emits `failed`
- **AND** the loop stops (episodes 4–8 are NOT attempted)

---

### Requirement: RunStartupCacheCleanupUseCase fires once at boot

The system SHALL expose:

```dart
class RunStartupCacheCleanupUseCase {
  Future<int> execute();
}
```

`execute` SHALL:

1. Read the user preference `download_cleanup.cache_auto_delete_enabled`
   from `SharedPreferences`. Default `true` when absent.
2. If disabled, return `0` immediately without enumerating.
3. If enabled, call `DownloadCleanupService.runCacheCleanup(olderThan:
   Duration(days: 30), now: DateTime.now())` and return its result.

The use case SHALL NOT block the boot sequence. The app boot SHALL
invoke it via `unawaited(...)` after the auth state has resolved.
A failure of the cleanup SHALL NOT prevent or delay the home page
from rendering.

The use case SHALL log at `info` level before attempting deletion:
`"cache cleanup: removing N items older than 30 days"`. The
detailed item ids SHALL be at `debug` level only.

#### Scenario: Cleanup runs when enabled

- **GIVEN** `cache_auto_delete_enabled` is unset (default true)
- **AND** 5 cache items are stale
- **WHEN** `execute()` is called
- **THEN** the result is `5`
- **AND** an info log line was emitted

#### Scenario: Cleanup is skipped when disabled

- **GIVEN** `cache_auto_delete_enabled` is `false`
- **WHEN** `execute()` is called
- **THEN** the result is `0`
- **AND** `DownloadCleanupService.runCacheCleanup` is NOT called

#### Scenario: Cleanup failure does not block app boot

- **GIVEN** `DownloadCleanupService.runCacheCleanup` throws
- **WHEN** the boot sequence calls `unawaited(execute())`
- **THEN** the home page renders normally
- **AND** the exception is logged but does not propagate

---

### Requirement: GetStorageSummaryUseCase

The system SHALL expose:

```dart
class StorageSummary {
  final int appDownloadsBytes;
  final int? deviceFreeBytes;
  final int downloadsCount;
  final int cacheCount;
}

class GetStorageSummaryUseCase {
  Future<StorageSummary> execute();
}
```

`execute` SHALL:

1. Call `DeviceStorageProbe.appDownloadsBytes()` and
   `DeviceStorageProbe.deviceFreeBytes()` in parallel.
2. Call `DownloadRepository.listAll()` and partition by `kind` to
   compute `downloadsCount` and `cacheCount`.
3. Return the assembled `StorageSummary`.

`execute` SHALL never throw. A null `deviceFreeBytes` is propagated
verbatim to the caller (UI displays `"indisponible"`).

#### Scenario: Summary aggregates probe and inventory

- **GIVEN** the downloads dir is 4.2 GB, free space is 12 GB, 6 items are downloads, 12 are cache
- **WHEN** `execute()` is called
- **THEN** the result is `{appDownloadsBytes: 4509715660, deviceFreeBytes: 12884901888, downloadsCount: 6, cacheCount: 12}`

---

### Requirement: Cache auto-delete preference persisted in SharedPreferences

The system SHALL persist the parent's choice to enable or disable
cache auto-deletion in `SharedPreferences` under the exact key:

```
download_cleanup.cache_auto_delete_enabled
```

The value SHALL be a `bool`. The default value SHALL be `true` (i.e.
auto-deletion enabled) when the key is absent — consistent with the
"out of the box" behavior of the cache/download split.

The Domain SHALL NOT depend on `SharedPreferences` directly — a
`CacheCleanupPreferences` repository abstraction (Application/
Infrastructure boundary) wraps the access.

The toggle SHALL be exposed in the Cache section of the manager
page (cf. UI requirement). Toggling it SHALL take effect at the
next call to `RunStartupCacheCleanupUseCase` (i.e. at the next app
boot). No retroactive cleanup is triggered.

#### Scenario: Default value when key is absent

- **GIVEN** `SharedPreferences` does not contain the key
- **WHEN** `CacheCleanupPreferences.isAutoDeleteEnabled()` is called
- **THEN** the result is `true`

#### Scenario: Disabling persists across restarts

- **GIVEN** the parent toggles auto-delete off
- **AND** the app is killed and relaunched
- **WHEN** the boot calls `RunStartupCacheCleanupUseCase.execute()`
- **THEN** the result is `0` (no cleanup performed)

---

### Requirement: Downloads page is gated by parent PIN

The system SHALL expose a Flutter route `/downloads` rendered by
`DownloadsPage` (`lib/ui/pages/downloads/downloads_page.dart`).

The route SHALL be reachable only after a successful
`VerifyManagementPinUseCase` challenge — the navigation entry
(cf. proposal D-7 for the host point) wraps the push in the existing
`showUnlockPinDialog` (or its equivalent for the management mode
entry). On a failed or cancelled challenge, the navigation SHALL
NOT happen.

When the active profile is the **main profile** (parent), the PIN
challenge MAY be skipped — the parent is already authenticated as
themselves. Implementations SHALL match the policy of the existing
`profile_management` entry-point on this point.

The page SHALL NOT be reachable from any kid profile route without
passing the challenge.

#### Scenario: Kid profile push triggers PIN challenge

- **GIVEN** the active profile is a kid
- **WHEN** the parent (or kid) tries to navigate to `/downloads`
- **THEN** the PIN dialog appears
- **AND** on cancel or wrong PIN, the navigation does not happen
- **AND** on correct PIN, the page is pushed

#### Scenario: Parent profile push skips challenge (matching profile-management policy)

- **GIVEN** the active profile is the main profile (parent)
- **WHEN** the parent navigates to `/downloads`
- **THEN** the page is pushed (PIN challenge follows the same policy
  as the `profile_management` route)

---

### Requirement: Downloads page renders storage summary, downloads, and cache sections

The `DownloadsPage` SHALL render, top to bottom:

1. **Storage header** (`storage_summary_header.dart`) — a card showing:
   - `"Kidflix occupe X"` where X is `appDownloadsBytes` formatted
     human-readable (e.g. `"4.2 Go"`).
   - `"Libre sur l'appareil : Y"` or `"Libre sur l'appareil :
     indisponible"` if `deviceFreeBytes == null`.
   - A line of two counters: `"N téléchargements · M en cache"`.
2. **Downloads section** — header `"Téléchargements"`, then:
   - If `inventory.downloads.isEmpty`: a placeholder
     `"Rien de téléchargé."`.
   - Otherwise: a list of `DownloadEntryTile` widgets, one per item.
3. **Cache section** (`cache_section.dart`) — collapsable, default
   collapsed, header `"Cache (N items, X)"`. When expanded:
   - A toggle row `"Auto-suppression après 30 jours sans visionnage"`
     bound to `cache_auto_delete_enabled`.
   - A list of `DownloadEntryTile` widgets for cache items.
   - A bottom button `"Vider le cache"` that triggers a confirmation
     dialog, then deletes all cache items via
     `DownloadRepository.deleteMovie/Episode` for each.

Each `DownloadEntryTile` SHALL display:

- Poster thumbnail (or grey fallback).
- Title (and parent series title for episodes, e.g. `"Pingu — S1E04"`).
- Size formatted human-readable.
- A subtitle indicating the trigger source and last-played age:
  - `"Téléchargé par Marie · vu il y a 2 j"` when both available.
  - `"Téléchargé par profil supprimé · jamais lu"` when applicable.
  - `"Vidéo inconnue · 450 Mo"` when catalog resolution failed.
- An action affordance:
  - For `kind == download`: `[Lire] [Ne plus garder] [Supprimer]`.
  - For `kind == cache`: `[Lire] [Garder] [Supprimer]`.

The `[Garder]` action calls `MarkAsDownloadUseCase`. The `[Ne plus
garder]` action calls `MarkAsCacheUseCase`. The `[Supprimer]` action
calls `DownloadRepository.deleteMovie/Episode` after a confirmation
dialog.

The page SHALL refresh its inventory on resume (i.e. after each
mutation, re-call `ListDownloadsUseCase` and rebuild). A pull-to-
refresh affordance SHALL also trigger the same.

#### Scenario: Empty page shows placeholder and zero counters

- **GIVEN** no files on disk
- **WHEN** the downloads page renders
- **THEN** the storage header shows `"Kidflix occupe 0 octets"` and `"0 téléchargements · 0 en cache"`
- **AND** the downloads section shows `"Rien de téléchargé."`
- **AND** the cache section is collapsed, header reads `"Cache (0 items, 0 octets)"`

#### Scenario: Vider le cache triggers confirmation then deletes all cache items

- **GIVEN** the cache section is expanded with 5 items totaling 1.2 Go
- **WHEN** the parent taps `"Vider le cache"` and confirms
- **THEN** all 5 items are deleted via the repository
- **AND** the page refreshes and the cache section is now empty

#### Scenario: Garder promotes a cache item and refreshes

- **GIVEN** a cache item `"Tchoupi à la mer"` is visible
- **WHEN** the parent expands its tile and taps `[Garder]`
- **THEN** `MarkAsDownloadUseCase` is invoked
- **AND** the page refreshes
- **AND** the item now appears in the Downloads section, no longer in Cache

---

### Requirement: Triggered profile resolution falls back when profile is missing

The `ListDownloadsUseCase` (and consequently the `DownloadsPage`) SHALL
resolve `triggeredByProfileId` against the current session's profile
list. If the id matches an existing profile, the display string SHALL
be `"Téléchargé par {profileName}"`. If the id does not match (profile
deleted), the display string SHALL be `"Téléchargé par profil
supprimé"`. If the id is `null` (rétro-classified entry, no manifest
record), the display string SHALL be `"Téléchargé par un autre appareil"`.

Profile deletion SHALL NOT cascade to download deletion. The Domain
service `DeleteProfileUseCase` (existing, in profile-management
capability) SHALL be unmodified by this change. Items triggered by a
deleted profile remain on disk in their previous `kind` until the
parent acts manually.

#### Scenario: Triggered profile no longer exists

- **GIVEN** a download has `triggeredByProfileId == "marie"`
- **AND** profile `"marie"` has been deleted
- **WHEN** the manager page renders the entry
- **THEN** the subtitle reads `"Téléchargé par profil supprimé · …"`

#### Scenario: Profile deletion does not delete downloads

- **GIVEN** profile `"marie"` triggered 3 downloads totaling 1.5 Go
- **WHEN** the parent deletes profile `"marie"`
- **THEN** the 3 downloads remain on disk, still classified `download`
- **AND** the manager page shows them as `"Téléchargé par profil supprimé"`

---

### Requirement: RunStartupCacheCleanupUseCase is wired to app boot

The application bootstrap SHALL invoke
`RunStartupCacheCleanupUseCase.execute()` exactly once per app
launch, scheduled via `unawaited(...)` after the auth state has
resolved to `Authenticated` and before/in parallel with the home
page first render.

The bootstrap SHALL NOT call this use case when:

- The auth state is `Anonymous` or `Bootstrapping` (no profile yet).
- The app is being run in a test harness without the production
  Riverpod overrides (test harnesses provide a NoopCleanup default
  via container override).

The bootstrap SHALL NOT call the use case more than once per launch
even if the auth state transitions back and forth (e.g. logout
then re-login). A `_didRunStartupCleanup` flag in the bootstrap
controller SHALL ensure single-shot semantics.

#### Scenario: Cleanup fires once after first auth

- **GIVEN** the app starts and the user authenticates
- **WHEN** the auth state becomes `Authenticated`
- **THEN** `RunStartupCacheCleanupUseCase.execute()` is invoked exactly once
- **AND** subsequent auth state changes during the same launch do not re-invoke it

#### Scenario: Anonymous bootstrap skips cleanup

- **GIVEN** the app starts and remains in `Anonymous` state (e.g. no session)
- **WHEN** the home page is not yet reachable
- **THEN** `RunStartupCacheCleanupUseCase.execute()` is NOT invoked
