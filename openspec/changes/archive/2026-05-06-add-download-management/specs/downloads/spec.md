## ADDED Requirements

### Requirement: DownloadKind enum

The system SHALL define an enum `DownloadKind` in
`lib/core/domain/model/download_kind.dart` (or co-located with the
existing download models) with exactly the following variants:

```dart
enum DownloadKind {
  cache,    // implicit, queued by the player at playback
  download, // explicit, the parent pressed "Télécharger"
}
```

`cache` is the default value for any download whose origin is the
implicit playback flow (the player started it under the hood).
`download` is set only by an explicit
`MarkAsDownloadUseCase.execute(...)` call (typically following the
"Télécharger" button + parent PIN challenge).

The semantic meaning:

- `cache`: this file is here for convenience but is **subject to
  auto-deletion** by `DownloadCleanupService`.
- `download`: this file is here **on purpose**, the parent wants it,
  do not auto-delete.

The enum SHALL serialize to/from JSON as the lowercase string
representation of the variant name (`"cache"` or `"download"`),
matching the manifest schema.

#### Scenario: Default kind for an implicit download

- **GIVEN** a movie play action triggers a fresh download via the player
- **WHEN** the download completes and the manifest entry is written
- **THEN** the entry's `kind` is `DownloadKind.cache`

#### Scenario: Explicit Télécharger sets download kind

- **GIVEN** a parent presses the `[Télécharger]` button on a movie
- **WHEN** `MarkAsDownloadUseCase.execute(...)` runs
- **THEN** the manifest entry's `kind` becomes `DownloadKind.download`

---

### Requirement: DownloadRepository.cacheMediaMetadata

The system SHALL expose a `cacheMediaMetadata` method on
`DownloadRepository`:

```dart
Future<void> cacheMediaMetadata({
  required String mediaId,
  required bool isEpisode,
  required String title,
  String? posterUrl,
  String? parentSeriesTitle,
});
```

The method SHALL persist `title`, `posterUrl`, and (for episodes)
`parentSeriesTitle` on the manifest entry for the given media.
Creates the entry with `kind == DownloadKind.cache` if absent. Other
existing fields (`kind`, `completedAt`, `lastPlayedAt`,
`triggeredByProfileId`) are preserved verbatim. Idempotent at value
level — a re-call with identical metadata SHALL NOT issue a manifest
write.

The method exists because `/catalog` filters items by **exact**
`age_category` of the active profile (per `API.md` § Catalogue). The
parent profile, opening the downloads manager, cannot resolve titles
of items targeting other age categories via the catalog. Persisting
title + poster at action time — when the caller (movie/series modal,
`[Télécharger]` button) holds the catalog object — bypasses the age
filter entirely. The manager UI prefers these cached fields over
`/catalog` lookups (cf. `download-management` spec).

#### Scenario: Caching from the modale stores title and poster

- **GIVEN** a movie modal renders with `Movie(id: "m-x", title: "Le Roi Lion", posterUrl: "https://…/roi.jpg")`
- **WHEN** the user taps `[Lire]` and the modale calls `cacheMediaMetadata(mediaId: "m-x", isEpisode: false, title: "Le Roi Lion", posterUrl: "https://…/roi.jpg")`
- **THEN** the manifest entry for `movies/m-x` exists with `cachedTitle == "Le Roi Lion"` and `cachedPosterUrl == "https://…/roi.jpg"`
- **AND** `kind` defaults to `DownloadKind.cache`

#### Scenario: Caching preserves existing manifest fields

- **GIVEN** `episodes/pingu-s01e04` is in the manifest with `kind == download`, `triggeredByProfileId == "marie"`, `lastPlayedAt == yesterday`
- **WHEN** `cacheMediaMetadata(mediaId: "pingu-s01e04", isEpisode: true, title: "Pingu skateur", parentSeriesTitle: "Pingu")` is called
- **THEN** the entry is updated with `cachedTitle == "Pingu skateur"` and `cachedParentSeriesTitle == "Pingu"`
- **AND** `kind`, `triggeredByProfileId`, and `lastPlayedAt` are unchanged

#### Scenario: Re-caching with identical values is a no-op

- **GIVEN** the manifest entry for `m-x` already has `cachedTitle == "Le Roi Lion"` and `cachedPosterUrl == "https://…/roi.jpg"`
- **WHEN** `cacheMediaMetadata` is called with identical title and posterUrl
- **THEN** no manifest write occurs

---

### Requirement: Download manifest sidecar persists applicative metadata

The system SHALL maintain a sidecar file
`${applicationDocumentsDirectory}/downloads/manifest.json` that holds
applicative metadata for each download present on disk. The file SHALL
be a JSON object whose keys are composite identifiers and whose values
are flat metadata objects:

```jsonc
{
  "movies/<id>": {
    "kind": "cache" | "download",
    "completedAt": "<ISO 8601 UTC>" | null,
    "lastPlayedAt": "<ISO 8601 UTC>" | null,
    "triggeredByProfileId": "<profile id>" | null,
    "cachedTitle": "<title captured at action time>" | null,
    "cachedPosterUrl": "<poster URL>" | null,
    "cachedParentSeriesTitle": "<series title, episodes only>" | null
  },
  "episodes/<id>": { ... same shape ... }
}
```

The `cachedTitle` / `cachedPosterUrl` / `cachedParentSeriesTitle` fields
are written by [DownloadRepository.cacheMediaMetadata] at action time
(player open, `[Télécharger]` button) and read by the manager UI as
the **primary** source of display metadata. They make the manager
robust to the strict age filter on `/catalog` (see that requirement).

The manifest SHALL be **dégradable**: its absence SHALL NOT prevent
any download flow from working. When the manifest does not exist or
is malformed, the system SHALL behave as if every entry were
`{kind: cache, completedAt: null, lastPlayedAt: <file.lastModified>,
triggeredByProfileId: null}`. A malformed manifest (JSON parse error)
SHALL emit a warning log and be treated as empty — the system SHALL
NOT crash and SHALL re-write a fresh empty manifest at the next
mutation.

The manifest SHALL be accessed exclusively through a
`DownloadManifestStore` infrastructure singleton in
`lib/infrastructure/downloads/manifest_store.dart`. This store SHALL:

1. Lazy-load the manifest into memory at first access.
2. Serialize all writes through a `synchronized.Lock` to prevent
   race conditions across concurrent download events.
3. Use **write-then-rename** atomicity for every persist operation:
   write a new `manifest.json.tmp`, then `File.rename` it to
   `manifest.json`. This ensures that a crash mid-write cannot
   leave a partially-written manifest on disk.

The `DownloadManifestStore` SHALL expose the following surface (used
by repositories and use cases):

```dart
abstract interface class DownloadManifestStore {
  Future<DownloadManifestEntry?> findFor({
    required String mediaId,
    required bool isEpisode,
  });
  Future<void> upsert({
    required String mediaId,
    required bool isEpisode,
    required DownloadManifestEntry entry,
  });
  Future<void> remove({
    required String mediaId,
    required bool isEpisode,
  });
  Future<List<({String key, DownloadManifestEntry entry})>> listAll();
}
```

The manifest SHALL NOT carry a schema version field at MVP. A
tolerant parser (ignore unknown keys) SHALL be used to keep room for
future extensions.

The manifest SHALL be removed (or its entry removed) when the
corresponding file is deleted via `deleteMovie/Episode`. After
deletion, the manifest SHALL NOT contain a stale entry.

#### Scenario: Fresh app start with no manifest

- **GIVEN** the app launches on a phone with no `manifest.json` and 3 existing `.mp4` files
- **WHEN** any consumer calls `listAll()` on the repository
- **THEN** all 3 entries are returned with `kind == cache`, `triggeredByProfileId == null`, `lastPlayedAt == file.lastModified`
- **AND** no exception is thrown

#### Scenario: Malformed manifest is recovered as empty

- **GIVEN** a `manifest.json` with the content `"this is not JSON"`
- **WHEN** the store is first accessed
- **THEN** a warning is logged
- **AND** the store behaves as if the manifest were empty
- **AND** the next mutation overwrites the file with valid JSON

#### Scenario: Atomic write survives crash mid-write

- **GIVEN** the store is mid-write (the `manifest.json.tmp` exists)
- **AND** the process crashes before the rename
- **WHEN** the app restarts
- **THEN** `manifest.json` still contains the previous valid content (the `.tmp` is orphaned and will be overwritten next time)

#### Scenario: Deletion removes manifest entry

- **GIVEN** `movies/abc` exists in the manifest with `kind == download`
- **WHEN** `deleteMovie("abc")` is called
- **THEN** the file is removed from disk
- **AND** the entry `movies/abc` is no longer present in the manifest

---

### Requirement: DownloadRepository.listAll enumerates all downloads

The Domain interface `DownloadRepository` SHALL expose:

```dart
Future<List<DownloadInventoryRecord>> listAll();
```

where `DownloadInventoryRecord` is a Domain value object:

```dart
class DownloadInventoryRecord {
  final String mediaId;
  final bool isEpisode;
  final int bytesOnDisk;
  final DownloadKind kind;
  final DateTime? completedAt;
  final DateTime? lastPlayedAt;
  final String? triggeredByProfileId;
}
```

`listAll` SHALL:

1. Scan `${applicationDocumentsDirectory}/downloads/movies/*.mp4` and
   `*.mp4.partial` ; same for `/downloads/episodes/`.
2. For each file, sum the `.mp4` and any matching `.partial` size to
   compute `bytesOnDisk`.
3. Look up the manifest entry by composite key (`movies/<id>` or
   `episodes/<id>`). If absent, fall back to `kind == cache`,
   `lastPlayedAt == file.lastModified`, others `null`.
4. Return the assembled list. Order is implementation-defined (the
   use case re-sorts for display).

`listAll` SHALL NOT issue any HTTP request. It is filesystem-only
and sub-100ms for typical inventories (~50 items).

`listAll` SHALL deduplicate: a media id with both a `.mp4` and a
`.partial` (e.g. partially-resumed) appears once with combined
`bytesOnDisk` and the manifest entry as-is.

#### Scenario: Empty disk returns empty list

- **GIVEN** `${documents}/downloads/` is empty (or absent)
- **WHEN** `listAll()` is called
- **THEN** the result is an empty list

#### Scenario: Mixed inventory with manifest hits and misses

- **GIVEN** `movies/abc.mp4` (100 MB) with manifest entry `kind: download`
- **AND** `episodes/pingu.mp4` (50 MB) without a manifest entry
- **WHEN** `listAll()` is called
- **THEN** the result has 2 records
- **AND** `abc` has `kind == download`
- **AND** `pingu` has `kind == cache` (default), `lastPlayedAt` set to file mtime

#### Scenario: Partial file contributes to bytesOnDisk

- **GIVEN** `movies/abc.mp4` (60 MB) and `movies/abc.mp4.partial` (15 MB)
- **WHEN** `listAll()` is called
- **THEN** the record for `abc` reports `bytesOnDisk == 78_643_200` (75 MB combined)

---

### Requirement: DownloadRepository.totalBytesOnDisk

The Domain interface `DownloadRepository` SHALL expose:

```dart
Future<int> totalBytesOnDisk();
```

`totalBytesOnDisk` SHALL return the sum of `bytesOnDisk` across all
records returned by `listAll()`. Implementations MAY compute it
directly via filesystem scan rather than consuming `listAll()`'s
result, as long as the value is consistent.

The method SHALL return `0` when no files exist or when the
downloads directory is absent. Never throws.

#### Scenario: Sum over downloads directory

- **GIVEN** files totaling 4_509_715_660 bytes in the downloads directory
- **WHEN** `totalBytesOnDisk()` is called
- **THEN** the result is `4_509_715_660`

#### Scenario: Zero on empty disk

- **GIVEN** an empty or absent downloads directory
- **WHEN** `totalBytesOnDisk()` is called
- **THEN** the result is `0`

---

### Requirement: DownloadRepository setMovieKind and setEpisodeKind

The Domain interface `DownloadRepository` SHALL expose:

```dart
Future<void> setMovieKind(String movieId, DownloadKind kind);
Future<void> setEpisodeKind(String episodeId, DownloadKind kind);
```

Each method SHALL:

1. Look up the manifest entry for the given id.
2. If absent, **create** an entry with the requested `kind`,
   `completedAt = null` (unless a `.mp4` exists, in which case use
   `file.lastModified`), `lastPlayedAt = file.lastModified` (or
   `null` if no file), `triggeredByProfileId = null`.
3. If present, **update** the `kind` field only — other fields
   (`completedAt`, `lastPlayedAt`, `triggeredByProfileId`) SHALL be
   preserved verbatim.
4. Persist the manifest atomically.

The methods SHALL be no-ops when the requested `kind` already
matches the current value: no manifest write, no error.

The methods SHALL be safe to call while a download is in-flight:
the manifest update happens out-of-band of the helper's stream and
does NOT inject any synchronization between the two — see design.md
D-8.

#### Scenario: Promote a cache item to download

- **GIVEN** `movies/abc` exists with `kind == cache`
- **WHEN** `setMovieKind("abc", DownloadKind.download)` is called
- **THEN** the manifest entry is updated to `kind == download`
- **AND** `lastPlayedAt`, `completedAt`, `triggeredByProfileId` are unchanged

#### Scenario: Set kind on an item with no manifest entry creates one

- **GIVEN** `movies/abc.mp4` exists on disk but no manifest entry
- **WHEN** `setMovieKind("abc", DownloadKind.download)` is called
- **THEN** a new manifest entry is created with `kind == download` and `lastPlayedAt == file.lastModified`

#### Scenario: Idempotent re-set is a no-op

- **GIVEN** `movies/abc` already has `kind == download`
- **WHEN** `setMovieKind("abc", DownloadKind.download)` is called
- **THEN** no manifest write occurs

---

### Requirement: DownloadRepository.markPlayed updates lastPlayedAt

The Domain interface `DownloadRepository` SHALL expose:

```dart
Future<void> markPlayed({
  required String mediaId,
  required bool isEpisode,
});
```

`markPlayed` SHALL:

1. Look up the manifest entry for the given id.
2. If absent, **create** an entry with `kind = cache`,
   `lastPlayedAt = DateTime.now()`, others `null`.
3. If present, update `lastPlayedAt = DateTime.now()`. Other fields
   are preserved.
4. Persist atomically.

`markPlayed` SHALL NOT bump `completedAt`, modify `kind`, or set
`triggeredByProfileId`.

`markPlayed` SHALL be called by `StartMoviePlaybackUseCase` and
`StartEpisodePlaybackUseCase` at the moment the player opens the
local file. The exact timing (open / first frame / dispose) is
implementation-defined ; the contract requires only that one call
per playback session occurs.

`markPlayed` SHALL be safe to call when no download exists for the
id (no `.mp4` on disk): the manifest entry is still created with
the timestamp. This handles the rare case where the player opens
a file that exists but has not yet been recorded.

#### Scenario: First playback creates a manifest entry

- **GIVEN** `movies/abc.mp4` exists on disk but no manifest entry
- **WHEN** `markPlayed(mediaId: "abc", isEpisode: false)` is called
- **THEN** a manifest entry is created with `kind == cache`, `lastPlayedAt == now`

#### Scenario: Repeat playback bumps lastPlayedAt only

- **GIVEN** `movies/abc` has manifest entry `kind: download, lastPlayedAt: yesterday`
- **WHEN** `markPlayed(mediaId: "abc", isEpisode: false)` is called
- **THEN** the entry has `kind == download` (preserved) and `lastPlayedAt == now`

---

### Requirement: kind getter on MovieDownload and EpisodeDownload snapshots

The system SHALL expose a getter `kind: DownloadKind` on both
`MovieDownload` and `EpisodeDownload` (the Domain value objects emitted
by `downloadMovie/Episode` streams). The value SHALL be hydrated by the
infrastructure helper from the manifest at the start of the streaming
session, and SHALL be carried verbatim on every subsequent snapshot for
that session.

If the manifest entry does not exist when the helper starts, the
getter SHALL return `DownloadKind.cache`.

The `kind` getter SHALL NOT participate in equality. Equality of
`MovieDownload` and `EpisodeDownload` remains based on
`(id, status, bytesReceived, updatedAt)` per the existing
requirement. A flip of `kind` mid-session SHALL NOT trigger a
re-emission on the stream.

A re-subscription to `downloadMovie/Episode` for the same id SHALL
re-read the manifest (so the new subscription sees the updated
`kind` if it was changed in the meantime).

#### Scenario: Snapshot carries kind from manifest

- **GIVEN** `movies/abc` is in the manifest with `kind == download`
- **WHEN** the player consumes `downloadMovie("abc")` and reads the first emitted snapshot
- **THEN** the snapshot's `kind` field is `DownloadKind.download`

#### Scenario: Mid-stream kind flip does not re-emit

- **GIVEN** an active subscription to `downloadMovie("abc")` showing `kind == cache`
- **WHEN** `setMovieKind("abc", DownloadKind.download)` is called from another part of the app
- **THEN** the active subscription does NOT receive a new event triggered solely by the kind change
- **AND** subsequent natural events (byte progress, status transition) carry the cached snapshot's original `kind == cache` (re-subscribe to see the new kind)

#### Scenario: Default kind when manifest is absent

- **GIVEN** no manifest entry exists for `movies/abc`
- **AND** a download for `abc` is initiated for the first time
- **WHEN** the first snapshot is emitted
- **THEN** the snapshot's `kind` is `DownloadKind.cache`
